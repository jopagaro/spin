//
//  GameViewModel.swift
//  RoyalSpin
//
//  Session state: credits, bet, free spins, and the spin lifecycle that ties the
//  math to the renderer and the audio.
//

import Combine
import SwiftUI

@MainActor
final class GameViewModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var credits: Int
    @Published private(set) var betPerLine: Int
    @Published private(set) var lastResult: SpinResult?
    @Published private(set) var isSpinning = false
    /// Credits animating upward after a win, so the number ticks up rather than jumping.
    @Published private(set) var displayCredits: Int
    @Published private(set) var freeSpinsRemaining = 0
    @Published private(set) var message: String?
    /// Which cabinet is being played. Set from the lobby.
    @Published private(set) var mode: ReelMode = .three
    /// Guaranteed-win spins the player has banked, mirrored from the engine.
    @Published private(set) var bonusSpins: Int = 0

    /// Rank and XP bar. Recomputed whenever lifetime XP changes.
    @Published private(set) var progress: RankProgress = .from(totalXP: 0)
    /// Set when a spin pushed the player up a rank, for the celebration banner.
    @Published private(set) var levelUp: LevelUp?
    /// When the timed collect was last taken. Nil means it has never been taken.
    @Published private(set) var lastCollected: Date?

    /// A rank promotion, with what it paid.
    struct LevelUp: Equatable {
        let level: Int
        let title: String
        let credits: Int
        let bonusSpins: Int
        let unlocked: ReelMode?
    }

    @Published var volatility: Volatility { didSet { machine.volatility = volatility; save() } }
    @Published var isMuted = false { didSet { AudioEngine.shared.isMuted = isMuted; save() } }
    /// Set briefly when a near miss lands, so the UI can call it out.
    @Published private(set) var nearMissBanner: NearMiss?

    // MARK: Config

    /// Starting balance, and what you get when you tap "reset". There is no way to
    /// buy credits and nothing to cash out — this is the entire economy.
    static let startingCredits = 5_000
    static let betLevels = [1, 2, 5, 10, 25, 50, 100]

    /// Guaranteed-win spins handed to a brand-new player, so the very first thing
    /// they do lands rather than whiffs. Onboarding only — these are not granted on
    /// purchase, so buying credits never changes the odds of a staked spin.
    static let welcomeBonusSpins = 3

    /// Bonus spins awarded when the reels hit the bonus.
    static let bonusSpinsPerTrigger = 3

    var totalBet: Int { betPerLine * mode.lineCount }
    var canSpin: Bool {
        !isSpinning && (bonusSpins > 0 || freeSpinsRemaining > 0 || credits >= totalBet)
    }
        var isFreeSpin: Bool { freeSpinsRemaining > 0 }

    /// What the big button should say.
    var spinButtonLabel: String {
        if bonusSpins > 0 { return "BONUS" }
        if freeSpinsRemaining > 0 { return "FREE" }
        return "SPIN"
    }

    func canAdjustBet(up: Bool) -> Bool {
        guard let i = Self.betLevels.firstIndex(of: betPerLine) else { return true }
        return up ? i < Self.betLevels.count - 1 : i > 0
    }

    // MARK: Internals

    private let machine: SlotMachine
    /// Lifetime XP. One point is earned for every credit won.
    private var totalXP: Int = 0
    private var countUpTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    private enum Key {
        static let mode = "rs.mode"
        static let bonusSpins = "rs.bonusSpins"
        static let welcomeGranted = "rs.welcomeGranted"
        static let credits = "rs.credits"
        static let bet = "rs.betPerLine"
        static let seed = "rs.seed"
        static let spinCount = "rs.spinCount"
        static let volatility = "rs.volatility"
        static let muted = "rs.muted"
        static let freeSpins = "rs.freeSpins"
        static let totalXP = "rs.totalXP"
        static let lastCollected = "rs.lastCollected"
    }

    init() {
        let d = UserDefaults.standard

        // A seed is minted once per install and kept. Combined with the persisted
        // spin count, this means a returning player continues their own unique
        // stream rather than replaying the same sequence from launch — which is
        // what "every player gets a different set" actually requires.
        let seed: UInt64
        if let stored = d.object(forKey: Key.seed) as? NSNumber {
            seed = stored.uint64Value
        } else {
            var entropy = SystemRandomNumberGenerator()
            seed = entropy.next()
            d.set(NSNumber(value: seed), forKey: Key.seed)
        }

        let vol = Volatility(rawValue: d.string(forKey: Key.volatility) ?? "") ?? .brutal
        let savedMode = ReelMode(rawValue: d.string(forKey: Key.mode) ?? "") ?? .three
        self.machine = SlotMachine(seed: seed,
                                   mode: savedMode,
                                   volatility: vol,
                                   nearMiss: .default)
        self.mode = savedMode
        self.volatility = vol

        let saved = d.object(forKey: Key.credits) as? Int
        self.credits = saved ?? Self.startingCredits
        self.displayCredits = saved ?? Self.startingCredits
        self.betPerLine = d.object(forKey: Key.bet) as? Int ?? 1
        self.freeSpinsRemaining = d.object(forKey: Key.freeSpins) as? Int ?? 0
        self.isMuted = d.object(forKey: Key.muted) as? Bool ?? false

        // Fast-forward the RNG to where the player left off.
        if let count = d.object(forKey: Key.spinCount) as? NSNumber {
            machine.advance(to: count.uint64Value)
        }

        // Restore banked bonus spins, and grant the welcome batch exactly once.
        //
        // The grant is gated on its own flag rather than on "are there zero bonus
        // spins?", because those two states are not the same thing: a player who has
        // simply spent their welcome spins also has zero, and inferring from the
        // count would hand them a fresh batch on every launch.
        var banked = d.object(forKey: Key.bonusSpins) as? Int ?? 0
        if !d.bool(forKey: Key.welcomeGranted) {
            banked += Self.welcomeBonusSpins
            d.set(true, forKey: Key.welcomeGranted)
        }
        machine.awardBonusSpins(banked)
        self.bonusSpins = machine.bonusSpinsRemaining

        self.totalXP = d.object(forKey: Key.totalXP) as? Int ?? 0
        self.progress = .from(totalXP: totalXP)
        self.lastCollected = d.object(forKey: Key.lastCollected) as? Date

        AudioEngine.shared.isMuted = isMuted
    }

    // MARK: Machine selection

    /// Switch cabinets from the lobby.
    ///
    /// Safe mid-session: the mode changes which paylines and paytable score a result,
    /// and how many reels are drawn, but never the reel strips or the RNG stream — so
    /// symbol weightings stay identical and no sequence is replayed.
    @discardableResult
    func selectMachine(mode newMode: ReelMode, volatility newVolatility: Volatility) -> Bool {
        guard newMode.isUnlocked(atLevel: progress.level) else {
            message = "REACH LEVEL \(newMode.unlockLevel) TO UNLOCK \(newMode.displayName.uppercased())"
            return false
        }
        machine.mode = newMode
        machine.volatility = newVolatility
        mode = newMode
        volatility = newVolatility
        // A bet that was legal on 20 lines can be unaffordable on 9, and vice versa.
        if totalBet > credits, let affordable = Self.betLevels.last(where: { $0 * newMode.lineCount <= credits }) {
            betPerLine = affordable
        }
        lastResult = nil
        message = nil
        nearMissBanner = nil
        save()
        return true
    }

    // MARK: Betting

    func adjustBet(by delta: Int) {
        guard !isSpinning else { return }
        let levels = Self.betLevels
        guard let i = levels.firstIndex(of: betPerLine) else { betPerLine = levels[0]; return }
        let next = max(0, min(levels.count - 1, i + delta))
        guard next != i else { return }
        betPerLine = levels[next]
        AudioEngine.shared.play(.uiTap, volume: 0.5)
        save()
    }

    func maxBet() {
        guard !isSpinning else { return }
        // Highest level we can actually afford, so the button never traps the player
        // in a bet they can't cover.
        let affordable = Self.betLevels.last { $0 * mode.lineCount <= credits }
        betPerLine = affordable ?? Self.betLevels[0]
        AudioEngine.shared.play(.uiTap, volume: 0.5)
        save()
    }

    // MARK: Spin lifecycle

    /// Produces the result and deducts the stake. The renderer then animates toward
    /// it and calls `spinDidFinish` when the last reel lands.
    func beginSpin() -> SpinResult? {
        guard canSpin else {
            if credits < totalBet && freeSpinsRemaining == 0 {
                message = "Out of credits — reset to keep playing."
                AudioEngine.shared.play(.bust, volume: 0.7)
            }
            return nil
        }

        countUpTask?.cancel()
        displayCredits = credits
        nearMissBanner = nil
        message = nil
        isSpinning = true

        // Bonus spins are a gift and cost nothing; ordinary free spins likewise.
        // Only a staked spin touches the balance, which is what keeps the published
        // RTP an honest description of what the player is paying for.
        if bonusSpins > 0 || freeSpinsRemaining > 0 {
            if bonusSpins == 0 { freeSpinsRemaining -= 1 }
        } else {
            credits -= totalBet
            displayCredits = credits
        }

        let result = machine.spin(betPerLine: betPerLine)
        lastResult = result
        bonusSpins = machine.bonusSpinsRemaining

        AudioEngine.shared.play(.leverPull)
        AudioEngine.shared.startLoop()

        save()
        return result
    }

    /// Called by the scene once every reel has settled.
    func spinDidFinish() {
        guard let result = lastResult else { isSpinning = false; return }
        AudioEngine.shared.stopLoop()
        isSpinning = false

        if result.totalWin > 0 {
            credits += result.totalWin
            // Progress is a reward for winning, not merely for pressing SPIN. One
            // credit won is one XP, so bigger hits move the rank bar farther and a
            // losing result does not move it at all.
            awardXP(result.totalWin)
            AudioEngine.shared.playWin(tier: result.tier)
            countUp(to: credits, tier: result.tier)

            awardBonusIfTriggered(result)
        } else {
            displayCredits = credits
            if !awardBonusIfTriggered(result), let nm = result.nearMiss {
                showNearMiss(nm)
            }
        }

        save()
    }

    /// Landing the bonus awards free spins *and* a handful of guaranteed-win spins.
    ///
    /// The guaranteed wins are earned on the reels rather than handed out with a
    /// purchase. That keeps the reward inside the game and keeps the store a plain
    /// exchange of money for credits, with no hidden change to the odds attached.
    @discardableResult
    private func awardBonusIfTriggered(_ result: SpinResult) -> Bool {
        guard result.freeSpinsAwarded > 0 else { return false }
        freeSpinsRemaining += result.freeSpinsAwarded
        machine.awardBonusSpins(Self.bonusSpinsPerTrigger)
        bonusSpins = machine.bonusSpinsRemaining
        message = "\(result.freeSpinsAwarded) FREE SPINS + \(Self.bonusSpinsPerTrigger) GUARANTEED!"
        AudioEngine.shared.play(.freeSpins)
        return true
    }

    // MARK: Progression

    /// Add XP and promote if the threshold is crossed.
    ///
    /// Handles multi-rank jumps: a single high-stakes spin early on can clear more
    /// than one rung, and the player should be paid for every one of them.
    private func awardXP(_ amount: Int) {
        guard amount > 0 else { return }
        let before = progress.level
        totalXP += amount
        progress = .from(totalXP: totalXP)
        guard progress.level > before else { return }

        var credited = 0
        var spins = 0
        for level in (before + 1) ... progress.level {
            credited += XPCurve.levelReward(for: level)
            spins += XPCurve.bonusSpinReward(for: level)
        }
        credits += credited
        if spins > 0 {
            machine.awardBonusSpins(spins)
            bonusSpins = machine.bonusSpinsRemaining
        }

        // Surface a cabinet that just became available, if any.
        let unlocked = ReelMode.allCases.first {
            $0.unlockLevel > before && $0.unlockLevel <= progress.level
        }

        levelUp = LevelUp(level: progress.level, title: progress.title,
                          credits: credited, bonusSpins: spins, unlocked: unlocked)
        AudioEngine.shared.play(.freeSpins, volume: 0.8)
    }

    func dismissLevelUp() { levelUp = nil }

    // MARK: Timed credits

    var freeCreditsReady: Bool { FreeCredits.isReady(since: lastCollected) }
    var freeCreditsAmount: Int { FreeCredits.amount(forLevel: progress.level) }
    var freeCreditsCountdown: String {
        FreeCredits.countdown(FreeCredits.secondsRemaining(since: lastCollected))
    }

    /// Take the timed collect. No-op if it isn't ready yet.
    @discardableResult
    func collectFreeCredits() -> Int {
        guard freeCreditsReady else { return 0 }
        let amount = freeCreditsAmount
        credits += amount
        displayCredits = credits
        lastCollected = Date()
        message = "+\(amount.formatted()) CREDITS COLLECTED"
        AudioEngine.shared.play(.coinChing, volume: 0.8)
        save()
        return amount
    }

    /// Reel `index` just landed — used for the per-reel knock and the scatter chime.
    func reelDidStop(index: Int) {
        AudioEngine.shared.playReelStop(index: index)

        // Chime if this reel landed a scatter, so banking toward the bonus is audible
        // reel by reel rather than only at the end.
        guard let grid = lastResult?.grid, grid.indices.contains(index) else { return }
        if grid[index].contains(where: { $0.isScatter }) {
            AudioEngine.shared.play(.scatterHit, volume: 0.6)
        }
    }

    private func showNearMiss(_ nm: NearMiss) {
        nearMissBanner = nm
        AudioEngine.shared.play(.nearMiss, volume: 0.75)
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            self?.nearMissBanner = nil
        }
    }

    /// Tick the credit counter up to the new total, with a coin sound per step.
    private func countUp(to target: Int, tier: WinTier) {
        countUpTask?.cancel()
        let start = displayCredits
        guard target > start else { displayCredits = target; return }

        // Bigger wins get a longer, more satisfying tally — but cap it so a jackpot
        // doesn't lock the player out of spinning for ten seconds.
        let duration: Double
        switch tier {
        case .jackpot: duration = 3.0
        case .mega:    duration = 2.2
        case .big:     duration = 1.6
        case .nice:    duration = 1.0
        default:       duration = 0.5
        }
        let steps = max(1, min(48, Int(duration * 24)))

        countUpTask = Task { [weak self] in
            for i in 1 ... steps {
                try? await Task.sleep(nanoseconds: UInt64(duration / Double(steps) * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                let t = Double(i) / Double(steps)
                // Ease out so it slows as it approaches the total.
                let eased = 1 - pow(1 - t, 2)
                self.displayCredits = start + Int(Double(target - start) * eased)
                if i % 3 == 0 { AudioEngine.shared.playCoin(step: i / 3) }
            }
            self?.displayCredits = target
        }
    }

    // MARK: Housekeeping

    func resetCredits() {
        credits = Self.startingCredits
        displayCredits = credits
        freeSpinsRemaining = 0
        message = nil
        AudioEngine.shared.play(.uiTap)
        save()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(credits, forKey: Key.credits)
        d.set(betPerLine, forKey: Key.bet)
        d.set(NSNumber(value: machine.spinCount), forKey: Key.spinCount)
        d.set(volatility.rawValue, forKey: Key.volatility)
        d.set(isMuted, forKey: Key.muted)
        d.set(freeSpinsRemaining, forKey: Key.freeSpins)
        d.set(mode.rawValue, forKey: Key.mode)
        d.set(bonusSpins, forKey: Key.bonusSpins)
        d.set(totalXP, forKey: Key.totalXP)
        if let lastCollected { d.set(lastCollected, forKey: Key.lastCollected) }
    }
}
