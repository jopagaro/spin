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
    @Published var volatility: Volatility { didSet { machine.volatility = volatility; save() } }
    @Published var isMuted = false { didSet { AudioEngine.shared.isMuted = isMuted; save() } }
    @Published var teaseEnabled = true {
        didSet {
            machine.nearMiss = teaseEnabled ? .default : .off
            save()
        }
    }

    /// Set briefly when a near miss lands, so the UI can call it out.
    @Published private(set) var nearMissBanner: NearMiss?

    // MARK: Config

    /// Starting balance, and what you get when you tap "reset". There is no way to
    /// buy credits and nothing to cash out — this is the entire economy.
    static let startingCredits = 5_000
    static let betLevels = [1, 2, 5, 10, 25, 50, 100]

    var totalBet: Int { betPerLine * Paylines.count }
    var canSpin: Bool { !isSpinning && (freeSpinsRemaining > 0 || credits >= totalBet) }
    var isFreeSpin: Bool { freeSpinsRemaining > 0 }

    // MARK: Internals

    private let machine: SlotMachine
    private var countUpTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    private enum Key {
        static let credits = "rs.credits"
        static let bet = "rs.betPerLine"
        static let seed = "rs.seed"
        static let spinCount = "rs.spinCount"
        static let volatility = "rs.volatility"
        static let muted = "rs.muted"
        static let tease = "rs.tease"
        static let freeSpins = "rs.freeSpins"
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
        let tease = d.object(forKey: Key.tease) as? Bool ?? true

        self.machine = SlotMachine(seed: seed,
                                   volatility: vol,
                                   nearMiss: tease ? .default : .off)
        self.volatility = vol
        self.teaseEnabled = tease

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

        AudioEngine.shared.isMuted = isMuted
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
        let affordable = Self.betLevels.last { $0 * Paylines.count <= credits }
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

        if freeSpinsRemaining > 0 {
            freeSpinsRemaining -= 1
        } else {
            credits -= totalBet
            displayCredits = credits
        }

        let result = machine.spin(betPerLine: betPerLine)
        lastResult = result

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
            AudioEngine.shared.playWin(tier: result.tier)
            countUp(to: credits, tier: result.tier)

            if result.freeSpinsAwarded > 0 {
                freeSpinsRemaining += result.freeSpinsAwarded
                message = "\(result.freeSpinsAwarded) FREE SPINS!"
                AudioEngine.shared.play(.freeSpins)
            }
        } else {
            displayCredits = credits
            if result.freeSpinsAwarded > 0 {
                freeSpinsRemaining += result.freeSpinsAwarded
                message = "\(result.freeSpinsAwarded) FREE SPINS!"
                AudioEngine.shared.play(.freeSpins)
            } else if let nm = result.nearMiss {
                showNearMiss(nm)
            }
        }

        save()
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
        d.set(teaseEnabled, forKey: Key.tease)
        d.set(freeSpinsRemaining, forKey: Key.freeSpins)
    }
}
