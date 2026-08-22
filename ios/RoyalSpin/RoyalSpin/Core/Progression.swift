//
//  Progression.swift
//  RoyalSpin
//
//  Ranks, XP and the free-credit timer.
//
//  This exists to solve the one structural problem a slot machine has: it doesn't
//  progress. Spin, result, spin — every session otherwise starts to feel identical.
//
//  **One credit won is one XP.** A loss does not move the bar, a small win nudges it,
//  and a jackpot can clear several ranks at once. That makes rank progress part of
//  the win celebration instead of a participation counter attached to every spin.
//  Free and guaranteed-spin payouts count as well: they are real wins in this
//  no-cash economy, and both reward pools are finite rather than farmable loops.
//

import Foundation

// MARK: - Ranks

/// The ladder, lowest to highest. Sixty rungs from the bottom of the scullery to
/// something no longer strictly mortal.
///
/// The low ranks are deliberately undignified. A player's first title should be
/// funny, not flattering — "Peasant" is a joke you're in on, and it makes "Baron"
/// forty levels later feel like it was worth something.
public enum Rank {

    public static let titles: [String] = [
        // The bottom — you have nothing and you are nobody.
        "Peasant",           // 1
        "Grunt",
        "Serf",
        "Mud Farmer",
        "Pot Scrubber",
        "Stable Hand",
        "Goose Herd",
        "Rookie",
        "Turnip Knight",
        "Apprentice",        // 10

        // Household staff — indoors at last.
        "Errand Runner",     // 11
        "Torch Bearer",
        "Cup Bearer",
        "Page",
        "Footman",
        "Cook",
        "Brewer",
        "Blacksmith",
        "Falconer",
        "Huntsman",          // 20

        // The court — you are now a person the King has heard of.
        "Minstrel",          // 21
        "Bard",
        "Jester",
        "Court Fool",
        "Scribe",
        "Herald",
        "Alchemist",
        "Astrologer",
        "Royal Physician",
        "Chamberlain",       // 30

        // Arms.
        "Squire",            // 31
        "Man-at-Arms",
        "Archer",
        "Crossbowman",
        "Sergeant",
        "Knight",
        "Knight Banneret",
        "Captain",
        "Commander",
        "Champion",          // 40

        // Gentry — land, and the trouble that comes with it.
        "Landholder",        // 41
        "Franklin",
        "Esquire",
        "Baronet",
        "Baron",
        "Viscount",
        "Count",
        "Earl",
        "Margrave",
        "Marquess",          // 50

        // The crown.
        "Duke",              // 51
        "Grand Duke",
        "Archduke",
        "Prince",
        "Crown Prince",
        "King",
        "High King",
        "Emperor",
        "Sovereign",
        "Immortal",          // 60
    ]

    public static var maxLevel: Int { titles.count }

    /// Artwork is being produced a band at a time. Keeping this list explicit
    /// makes a missing image fall back cleanly instead of asking SwiftUI for an
    /// asset that does not exist.
    public static let illustratedAssetNames: [String] = [
        "rank_01_peasant",
        "rank_02_grunt",
        "rank_03_serf",
        "rank_04_mud_farmer",
        "rank_05_pot_scrubber",
        "rank_06_stable_hand",
        "rank_07_goose_herd",
        "rank_08_rookie",
        "rank_09_turnip_knight",
        "rank_10_apprentice",
        "rank_11_errand_runner",
        "rank_12_torch_bearer",
        "rank_13_cup_bearer",
        "rank_14_page",
        "rank_15_footman",
        "rank_16_cook",
        "rank_17_brewer",
        "rank_18_blacksmith",
        "rank_19_falconer",
        "rank_20_huntsman",
    ]

    public static func illustratedAssetName(for level: Int) -> String? {
        guard illustratedAssetNames.indices.contains(level - 1) else { return nil }
        return illustratedAssetNames[level - 1]
    }

    public static func title(for level: Int) -> String {
        titles[min(max(level, 1), maxLevel) - 1]
    }

    /// Coarse band, for colouring a badge without a 60-entry switch.
    public static func band(for level: Int) -> Band {
        switch level {
        case ..<11:  return .peasantry
        case ..<21:  return .household
        case ..<31:  return .court
        case ..<41:  return .arms
        case ..<51:  return .gentry
        default:     return .crown
        }
    }

    public enum Band: String, Sendable {
        case peasantry, household, court, arms, gentry, crown

        public var displayName: String {
            switch self {
            case .peasantry: return "Peasantry"
            case .household: return "Household"
            case .court:     return "The Court"
            case .arms:      return "Arms"
            case .gentry:    return "Gentry"
            case .crown:     return "The Crown"
            }
        }
    }
}

// MARK: - The curve

public enum XPCurve {

    /// XP required to advance *from* `level` to `level + 1`.
    ///
    /// `40 · level^1.6`. The exponent is what shapes the whole experience: the first
    /// rung costs 40 XP, so the first 40 credits a player wins teach them that the
    /// ladder exists. By level 40 a rung costs ~15,000 credits won, which takes a
    /// sustained run of play.
    ///
    /// Total to reach Immortal is about 1.1M credits won. Because wins arrive in
    /// bursts, two players can reach the ceiling on very different timelines.
    public static func xpToAdvance(from level: Int) -> Int {
        guard level >= 1, level < Rank.maxLevel else { return 0 }
        return Int((40.0 * pow(Double(level), 1.6)).rounded())
    }

    /// Cumulative XP required to *be* at `level`.
    public static func totalXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1 ..< level).reduce(0) { $0 + xpToAdvance(from: $1) }
    }

    /// The level a given lifetime XP total corresponds to.
    public static func level(forTotalXP xp: Int) -> Int {
        var level = 1
        var remaining = xp
        while level < Rank.maxLevel {
            let need = xpToAdvance(from: level)
            if remaining < need { break }
            remaining -= need
            level += 1
        }
        return level
    }

    /// Credits granted on reaching `level`.
    ///
    /// Deliberately modest — a garnish, not an income. If levelling paid enough to
    /// live on, credits would stop being scarce, and every other reward in the game
    /// (the timed collect, a bonus round, the store) would lose its meaning along
    /// with it.
    public static func levelReward(for level: Int) -> Int {
        50 * level
    }

    /// Milestone levels also hand over guaranteed-win spins.
    public static func bonusSpinReward(for level: Int) -> Int {
        level % 10 == 0 ? 3 : 0
    }
}

// MARK: - Unlocks

extension ReelMode {
    /// Level at which this cabinet becomes playable.
    ///
    /// Empire is locked at first. Both machines being available from the start made
    /// the lobby a chooser rather than a destination; gating the high-stakes cabinet
    /// turns Kingdom from "the tamer one" into the road to somewhere, and gives the
    /// early ranks something to be for.
    /// Level 5 requires 761 lifetime credits won: reachable in a strong first
    /// session, while still making the second cabinet feel earned rather than given.
    public var unlockLevel: Int {
        switch self {
        case .three: return 1
        case .five:  return 5
        }
    }

    public func isUnlocked(atLevel level: Int) -> Bool { level >= unlockLevel }
}

// MARK: - Progress snapshot

/// Everything the UI needs to draw the rank badge and XP bar.
///
/// Named `RankProgress` rather than `Progress` because Foundation already exports a
/// `Progress` class, and the bare name silently resolves to that one instead.
public struct RankProgress: Equatable, Sendable {
    public let level: Int
    public let title: String
    public let band: Rank.Band
    /// XP earned since reaching the current level.
    public let xpIntoLevel: Int
    /// XP needed to leave the current level. Zero at max.
    public let xpForNextLevel: Int
    public let totalXP: Int

    public var isMaxLevel: Bool { level >= Rank.maxLevel }

    /// 0…1 for the bar. Full at max level rather than empty, which reads as finished
    /// instead of broken.
    public var fraction: Double {
        guard !isMaxLevel, xpForNextLevel > 0 else { return 1 }
        return min(1, max(0, Double(xpIntoLevel) / Double(xpForNextLevel)))
    }

    public static func from(totalXP xp: Int) -> RankProgress {
        let level = XPCurve.level(forTotalXP: xp)
        let base = XPCurve.totalXP(toReach: level)
        return RankProgress(
            level: level,
            title: Rank.title(for: level),
            band: Rank.band(for: level),
            xpIntoLevel: xp - base,
            xpForNextLevel: XPCurve.xpToAdvance(from: level),
            totalXP: xp
        )
    }
}

// MARK: - Timed free credits

/// The return loop.
///
/// A refill on a timer is what actually drives daily actives in this genre — more
/// than levels and more than ads — because it gives a reason to open the app that
/// exists whether or not the player felt like playing. It also creates the scarcity
/// the rest of the economy needs: a balance that can run dry is what makes a refill,
/// a bonus round, or a purchase mean anything.
public enum FreeCredits {

    /// How long between collections.
    public static let interval: TimeInterval = 3 * 60 * 60

    /// Payout, scaled by rank so the timer keeps pace with rising bet sizes. A
    /// Peasant's 3-hour collect covers 50 spins on Kingdom; an Emperor's covers a
    /// similar number at the stakes they actually play.
    public static func amount(forLevel level: Int) -> Int {
        250 + 75 * (level - 1)
    }

    /// Seconds until the next collection, or 0 when one is ready.
    public static func secondsRemaining(since last: Date?, now: Date = Date()) -> TimeInterval {
        guard let last else { return 0 }
        return max(0, interval - now.timeIntervalSince(last))
    }

    public static func isReady(since last: Date?, now: Date = Date()) -> Bool {
        secondsRemaining(since: last, now: now) <= 0
    }

    /// "2h 14m" / "48s" — short enough for a button label.
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}
