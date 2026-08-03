//
//  SlotMath.swift
//  RoyalSpin
//
//  Pure-Swift game math. No UIKit / SwiftUI / SceneKit imports — this file is
//  deliberately dependency-free so the exact same code can be compiled into the
//  iOS app *and* into the command-line RTP simulator in tools/rtp_sim.
//
//  This is the single source of truth for the game's odds. The Kotlin file
//  android/app/src/main/java/com/royalspin/core/SlotMath.kt is a line-for-line
//  port; if you change one, change the other and re-run both simulators.
//

import Foundation

// MARK: - Symbols

/// The royal court. Order matters: `rawValue` is used as the reel-strip encoding
/// and as the index into the art atlas, so do not renumber these casually.
public enum Symbol: Int, CaseIterable, Codable, Sendable {
    case shield    = 0   // low
    case chalice   = 1   // low
    case sceptre   = 2   // low
    case joker     = 3   // mid — traditional playing-card harlequin
    case knight    = 4   // mid
    case princess  = 5   // mid-high
    case prince    = 6   // mid-high
    case queen     = 7   // high
    case king      = 8   // high
    case crown     = 9   // WILD — substitutes for everything except the seal
    case royalSeal = 10  // SCATTER — pays anywhere, awards free spins

    /// Asset basename. The art pipeline looks for `sym_<assetName>` in the
    /// bundle, so these strings are load-bearing. See ASSETS.md.
    public var assetName: String {
        switch self {
        case .shield:    return "shield"
        case .chalice:   return "chalice"
        case .sceptre:   return "sceptre"
        case .joker:     return "joker"
        case .knight:    return "knight"
        case .princess:  return "princess"
        case .prince:    return "prince"
        case .queen:     return "queen"
        case .king:      return "king"
        case .crown:     return "crown"
        case .royalSeal: return "royal_seal"
        }
    }

    public var displayName: String {
        switch self {
        case .shield:    return "Shield"
        case .chalice:   return "Chalice"
        case .sceptre:   return "Sceptre"
        case .joker:     return "Joker"
        case .knight:    return "Knight"
        case .princess:  return "Princess"
        case .prince:    return "Prince"
        case .queen:     return "Queen"
        case .king:      return "King"
        case .crown:     return "Crown"
        case .royalSeal: return "Royal Seal"
        }
    }

    public var isWild: Bool    { self == .crown }
    public var isScatter: Bool { self == .royalSeal }
}

// MARK: - Volatility

/// How the game feels. RTP and hit frequency are *independent* knobs — this enum
/// exists because conflating them is the classic slot-design mistake.
///
/// A high-volatility machine can return the same total percentage as a low-volatility
/// one while paying on a fraction as many spins, because the wins that do land are
/// far bigger. The lever that does most of the work is the three-of-a-kind row: on
/// `.brutal` the three low symbols pay *nothing* for three in a row, which deletes
/// the flood of trivial wins that otherwise drives hit frequency into the 30s.
///
/// Measured numbers live in design/math.md. Re-run `tools/rtp_sim` after any edit.
public enum Volatility: String, CaseIterable, Codable, Sendable {
    /// Hits constantly, pays little. Closest to a low-volatility online slot.
    case gentle
    /// Middle of the road. Roughly a real Vegas floor machine.
    case classic
    /// Rarely hits, pays enormously when it does. Hardest setting.
    case brutal

    public var displayName: String {
        switch self {
        case .gentle:  return "Gentle"
        case .classic: return "Classic"
        case .brutal:  return "Royal Ruin"
        }
    }

    public var blurb: String {
        switch self {
        case .gentle:  return "Frequent small wins. Your balance drifts."
        case .classic: return "A real casino floor machine."
        case .brutal:  return "Almost never pays. When it does, you'll know."
        }
    }
}

// MARK: - Paytable

public enum Paytable {

    /// Five-reel ladder: pays for 3, 4 and 5 of a kind, as multiples of the line bet.
    /// Index 0 = three of a kind, 1 = four, 2 = five.
    ///
    /// **These values are measured and signed off** — 94.85% / 89.86% / 89.86% RTP at
    /// 35.32% / 21.49% / 8.75% hit frequency. Do not adjust them casually; re-run
    /// `tools/rtp_sim` if you do.
    ///
    /// A zero in slot 0 means that symbol doesn't pay for three in a row — the
    /// primary hit-frequency control, not a bug.
    private static func ladder(_ symbol: Symbol, _ v: Volatility) -> [Int] {
        switch v {

        // Everything pays from three.
        case .gentle:
            switch symbol {
            case .shield:    return [8,   30,  90]
            case .chalice:   return [8,   35,  110]
            case .sceptre:   return [11,  45,  140]
            case .joker:     return [15,  60,  180]
            case .knight:    return [18,  70,  230]
            case .princess:  return [22,  110, 350]
            case .prince:    return [28,  140, 450]
            case .queen:     return [45,  220, 750]
            case .king:      return [60,  300, 1100]
            case .crown:     return [80,  600, 3000]
            case .royalSeal: return [0, 0, 0]
            }

        // Lows need four. Mids still pay from three, but thinly.
        case .classic:
            switch symbol {
            case .shield:    return [0,   36,  140]
            case .chalice:   return [0,   40,  155]
            case .sceptre:   return [0,   50,  185]
            case .joker:     return [8,   72,  255]
            case .knight:    return [10,  90,  330]
            case .princess:  return [17,  145, 500]
            case .prince:    return [22,  200, 680]
            case .queen:     return [35,  345, 1280]
            case .king:      return [48,  500, 2000]
            case .crown:     return [90,  1000, 5500]
            case .royalSeal: return [0, 0, 0]
            }

        // Nothing below Princess pays for three. Almost every spin is a loss; the
        // payout is concentrated into rare four- and five-of-a-kind hits.
        case .brutal:
            switch symbol {
            case .shield:    return [0,   30,  200]
            case .chalice:   return [0,   35,  240]
            case .sceptre:   return [0,   45,  300]
            case .joker:     return [0,   70,  450]
            case .knight:    return [0,   90,  600]
            case .princess:  return [0,   150, 1000]
            case .prince:    return [0,   220, 1500]
            case .queen:     return [0,   400, 3000]
            case .king:      return [0,   650, 5000]
            case .crown:     return [0,   1500, 25000]
            case .royalSeal: return [0, 0, 0]
            }
        }
    }

    /// Three-reel pays. Three of a kind is the only winning shape here, so there is a
    /// single value per symbol rather than a ladder.
    ///
    /// These are a separate, independently tuned table — the five-reel numbers cannot
    /// be reused, because with only 5 paylines and no 4-or-5-of-a-kind the expected
    /// return per spin is a completely different calculation.
    private static func triple(_ symbol: Symbol, _ v: Volatility) -> Int {
        switch v {
        case .gentle:
            switch symbol {
            case .shield:    return 11
            case .chalice:   return 13
            case .sceptre:   return 15
            case .joker:     return 22
            case .knight:    return 28
            case .princess:  return 40
            case .prince:    return 52
            case .queen:     return 78
            case .king:      return 115
            case .crown:     return 740
            case .royalSeal: return 0
            }
        case .classic:
            switch symbol {
            case .shield:    return 7
            case .chalice:   return 8
            case .sceptre:   return 10
            case .joker:     return 20
            case .knight:    return 26
            case .princess:  return 42
            case .prince:    return 58
            case .queen:     return 90
            case .king:      return 135
            case .crown:     return 880
            case .royalSeal: return 0
            }
        // The three low symbols pay nothing. They're also the most common, so that
        // alone removes most winning combinations — which is what makes this profile
        // rarely hit while still returning a fair percentage, concentrated into the
        // high symbols.
        //
        // Values scaled down ~10% from a first pass that measured 101.80% RTP — an
        // over-100% table means the house loses money on every spin, which is a bug
        // however generous you want to be.
        case .brutal:
            switch symbol {
            case .shield:    return 0
            case .chalice:   return 0
            case .sceptre:   return 0
            case .joker:     return 23
            case .knight:    return 30
            case .princess:  return 47
            case .prince:    return 61
            case .queen:     return 89
            case .king:      return 131
            case .crown:     return 890
            case .royalSeal: return 0
            }
        }
    }

    public static func linePay(_ symbol: Symbol, count: Int,
                               volatility: Volatility, mode: ReelMode) -> Int {
        guard count >= 3 else { return 0 }
        switch mode {
        case .three:
            return count >= 3 ? triple(symbol, volatility) : 0
        case .five:
            guard count <= 5 else { return 0 }
            return ladder(symbol, volatility)[count - 3]
        }
    }

    /// Scatter pays as a multiple of the *total bet* (not the line bet), because
    /// scatters ignore paylines and land anywhere on the grid.
    ///
    /// On three reels only three scatters are reachable, and three seals are far
    /// rarer there (one per reel rather than three of five), so that single tier pays
    /// much more than its five-reel equivalent.
    public static func scatterPay(count: Int, volatility: Volatility, mode: ReelMode) -> Int {
        switch mode {
        case .three:
            guard count >= 3 else { return 0 }
            switch volatility {
            case .gentle:  return 60
            case .classic: return 90
            case .brutal:  return 135
            }
        case .five:
            switch (volatility, count) {
            case (.gentle,  3): return 3
            case (.gentle,  4): return 15
            case (.gentle,  5): return 100
            case (.classic, 3): return 2
            case (.classic, 4): return 20
            case (.classic, 5): return 200
            case (.brutal,  3): return 0    // three seals award spins but no cash
            case (.brutal,  4): return 25
            case (.brutal,  5): return 500
            default:            return 0
            }
        }
    }

    /// Free spins awarded by a scatter hit. Kept identical across profiles — the
    /// bonus round is the reward for surviving, so it shouldn't get rarer as the
    /// game gets harsher.
    public static func freeSpins(scatterCount: Int) -> Int {
        switch scatterCount {
        case 3:  return 8
        case 4:  return 12
        case 5:  return 20
        default: return 0
        }
    }
}

// MARK: - Paylines

/// How many reels the machine runs. A player-facing setting, not a build constant.
///
/// The two modes are genuinely different games, not a cosmetic switch:
///
/// - **Five** is the modern shape — 5×3 with 20 paylines and a 3/4/5-of-a-kind
///   ladder, so a line can pay three different amounts.
/// - **Three** is the classic shape — 3×3 with 5 paylines where three of a kind is
///   the *only* winning combination, so each symbol has a single pay value.
///
/// Three also looks considerably better on a phone: the cabinet's reel window is
/// 702 × 569, so five square symbols across it are 140px each while three are 190px.
/// That's why it exists as an option.
///
/// Every mode has its own measured RTP — see design/math.md.
public enum ReelMode: String, CaseIterable, Codable, Sendable {
    case three
    case five

    public var reels: Int { self == .three ? 3 : 5 }

    public var displayName: String {
        switch self {
        case .three: return "3 Reels"
        case .five:  return "5 Reels"
        }
    }

    public var blurb: String {
        switch self {
        case .three: return "Classic 3×3, 5 lines. Bigger symbols, three of a kind only."
        case .five:  return "Modern 5×3, 20 lines. Pays for 3, 4 or 5 in a row."
        }
    }

    /// Each entry is the row index (0 = top, 2 = bottom) the line occupies on each
    /// reel, left to right.
    public var paylines: [[Int]] {
        switch self {
        // Nine lines, not the classic five.
        //
        // This is the lever that makes the three-reel machine the welcoming one.
        // RTP is *independent* of line count — the return per line-bet is the same
        // whether you play 5 lines or 9 — but every extra line is another chance to
        // hit, so hit frequency rises in step. Five lines measured 14.8%; nine takes
        // it to roughly 25% without moving the payout percentage at all.
        case .three:
            return [
                [1, 1, 1],  // 1  straight middle
                [0, 0, 0],  // 2  straight top
                [2, 2, 2],  // 3  straight bottom
                [0, 1, 2],  // 4  diagonal down
                [2, 1, 0],  // 5  diagonal up
                [0, 1, 0],  // 6  shallow V, top
                [2, 1, 2],  // 7  shallow V, bottom
                [1, 0, 1],  // 8  peak
                [1, 2, 1],  // 9  valley
            ]
        case .five:
            return [
                [1, 1, 1, 1, 1],  //  1  straight middle
                [0, 0, 0, 0, 0],  //  2  straight top
                [2, 2, 2, 2, 2],  //  3  straight bottom
                [0, 1, 2, 1, 0],  //  4  V
                [2, 1, 0, 1, 2],  //  5  inverted V
                [0, 0, 1, 2, 2],  //  6
                [2, 2, 1, 0, 0],  //  7
                [1, 2, 2, 2, 1],  //  8
                [1, 0, 0, 0, 1],  //  9
                [1, 2, 1, 0, 1],  // 10
                [1, 0, 1, 2, 1],  // 11
                [0, 1, 1, 1, 0],  // 12
                [2, 1, 1, 1, 2],  // 13
                [0, 1, 0, 1, 0],  // 14  zigzag top
                [2, 1, 2, 1, 2],  // 15  zigzag bottom
                [1, 1, 0, 1, 1],  // 16
                [1, 1, 2, 1, 1],  // 17
                [0, 0, 1, 0, 0],  // 18
                [2, 2, 1, 2, 2],  // 19
                [0, 2, 0, 2, 0],  // 20  full zigzag
            ]
        }
    }

    public var lineCount: Int { paylines.count }
}

public enum Paylines {
    public static let rows = 3
    /// Widest mode, for sizing fixed-length buffers.
    public static let maxReels = 5
}

// MARK: - Reel strips

public enum ReelStrips {

    /// Symbol counts per reel. Reel 1 is the most generous and each subsequent
    /// reel gets stingier with the high symbols — this is what makes a game feel
    /// like it "almost" hit, because the left of the line fills in far more often
    /// than the right. Changing any number here changes the RTP; re-run the
    /// simulator (`tools/rtp_sim`) after editing.
    private static let composition: [[Symbol: Int]] = [
        // Reel 1
        [.king: 4, .queen: 4, .prince: 5, .princess: 5, .knight: 6,
         .joker: 6, .sceptre: 7, .chalice: 7, .shield: 8, .crown: 2, .royalSeal: 2],
        // Reel 2
        [.king: 3, .queen: 4, .prince: 4, .princess: 5, .knight: 6,
         .joker: 6, .sceptre: 7, .chalice: 8, .shield: 8, .crown: 3, .royalSeal: 2],
        // Reel 3
        [.king: 3, .queen: 3, .prince: 4, .princess: 4, .knight: 6,
         .joker: 6, .sceptre: 8, .chalice: 8, .shield: 9, .crown: 3, .royalSeal: 2],
        // Reel 4
        [.king: 2, .queen: 3, .prince: 4, .princess: 4, .knight: 6,
         .joker: 7, .sceptre: 8, .chalice: 8, .shield: 9, .crown: 3, .royalSeal: 2],
        // Reel 5
        [.king: 2, .queen: 2, .prince: 3, .princess: 4, .knight: 6,
         .joker: 7, .sceptre: 8, .chalice: 9, .shield: 10, .crown: 3, .royalSeal: 2],
    ]

    /// The physical strips, built once. Each strip is shuffled deterministically
    /// and then de-clumped so the same symbol never appears three times in a row —
    /// long runs look broken when they scroll past on the cylinder.
    public static let strips: [[Symbol]] = composition.enumerated().map { index, counts in
        buildStrip(counts: counts, seed: UInt64(0x9E3779B97F4A7C15 &+ UInt64(index)))
    }

    private static func buildStrip(counts: [Symbol: Int], seed: UInt64) -> [Symbol] {
        var pool: [Symbol] = []
        // Iterate CaseIterable rather than the dictionary so strip construction is
        // stable across runs — Dictionary ordering is not.
        for symbol in Symbol.allCases {
            let n = counts[symbol] ?? 0
            pool.append(contentsOf: repeatElement(symbol, count: n))
        }

        var rng = Xoshiro256(seed: seed)
        // Fisher–Yates with our own PRNG so Swift's stdlib shuffle changes can
        // never silently alter the paytable.
        for i in stride(from: pool.count - 1, to: 0, by: -1) {
            let j = Int(rng.next(upperBound: UInt64(i + 1)))
            pool.swapAt(i, j)
        }

        return declump(pool, rng: &rng)
    }

    /// Push apart runs of 3+ identical symbols by swapping the offender with a
    /// random later position that doesn't create a new run. Purely cosmetic — it
    /// permutes the strip, so the symbol counts (and therefore the odds) are
    /// untouched.
    private static func declump(_ input: [Symbol], rng: inout Xoshiro256) -> [Symbol] {
        var strip = input
        let n = strip.count
        for _ in 0 ..< 8 {  // a few passes is plenty; bail out rather than loop forever
            var clean = true
            for i in 0 ..< n {
                let a = strip[i]
                let b = strip[(i + 1) % n]
                let c = strip[(i + 2) % n]
                guard a == b, b == c else { continue }
                clean = false
                // Find somewhere to send the middle one.
                for _ in 0 ..< 32 {
                    let j = Int(rng.next(upperBound: UInt64(n)))
                    let idx = (i + 1) % n
                    guard j != idx else { continue }
                    strip.swapAt(idx, j)
                    break
                }
            }
            if clean { break }
        }
        return strip
    }
}

// MARK: - RNG

/// xoshiro256** — small, fast, and statistically solid for game use.
///
/// We ship our own rather than using `Int.random(in:)` for two reasons: the
/// sequence is reproducible from a seed (so a bug report can be replayed exactly),
/// and the algorithm can't shift under us when the Swift stdlib changes. It is
/// *not* cryptographic, which is fine — nothing here is worth money. The seed
/// itself does come from the system CSPRNG, so two installs never share a stream.
public struct Xoshiro256: RandomNumberGenerator, Sendable {
    private var s: (UInt64, UInt64, UInt64, UInt64)

    public init(seed: UInt64) {
        // SplitMix64 to spread a single seed value across all four words.
        var z = seed
        func splitmix() -> UInt64 {
            z &+= 0x9E3779B97F4A7C15
            var x = z
            x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
            x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
            return x ^ (x >> 31)
        }
        s = (splitmix(), splitmix(), splitmix(), splitmix())
        // A zero state is a fixed point for xoshiro; make it impossible.
        if s == (0, 0, 0, 0) { s.0 = 0x9E3779B97F4A7C15 }
    }

    /// Seeds from the system CSPRNG. Use this for real play.
    public init() {
        var sys = SystemRandomNumberGenerator()
        self.init(seed: sys.next())
    }

    public mutating func next() -> UInt64 {
        let result = rotl(s.1 &* 5, 7) &* 9
        let t = s.1 << 17
        s.2 ^= s.0
        s.3 ^= s.1
        s.1 ^= s.2
        s.0 ^= s.3
        s.2 ^= t
        s.3 = rotl(s.3, 45)
        return result
    }

    /// Unbiased bounded draw via rejection sampling. The naive `next() % n` is
    /// skewed toward small values whenever n doesn't divide 2^64, which on a
    /// 56-stop reel strip would quietly bend the paytable.
    public mutating func next(upperBound: UInt64) -> UInt64 {
        precondition(upperBound > 0)
        let threshold = (0 &- upperBound) % upperBound
        while true {
            let r = next()
            if r >= threshold { return r % upperBound }
        }
    }

    private func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x << k) | (x >> (64 &- k))
    }
}

// MARK: - Spin results

// MARK: - Near miss & anticipation

/// Tuning for the "so close" effect.
///
/// **How this is implemented, and why it doesn't cheat.**
///
/// The obvious way to manufacture near misses is the Telnaes trick: weight the reel
/// strips so that blanks sit next to jackpot symbols. That works, but it's baked into
/// the odds and it's fiddly to tune.
///
/// Instead we do it *post hoc, on losing spins only*. The RNG draws an honest result.
/// If that result is a loss, we may re-roll a single reel — and we only accept the
/// new stop if the spin is **still a loss**. A nudge can therefore never turn a losing
/// spin into a winning one, nor the reverse. The set of paying outcomes and their
/// probabilities are untouched, so RTP, hit frequency and variance are all bit-for-bit
/// identical whether this is on or off. `tools/rtp_sim` verifies exactly that.
///
/// What changes is only *which* losing grid you see: instead of an arbitrary blank,
/// you see four kings and a king one row off the line. Same loss, much better story.
public struct NearMissConfig: Codable, Sendable {
    /// Master switch.
    public var enabled: Bool
    /// Fraction of losing spins that get nudged into a tease, 0...1. At 1.0 every
    /// loss that *can* be dressed up will be, which quickly reads as fake — the
    /// effect works because it's occasional.
    public var rate: Double
    /// Only tease with symbols at least this valuable (raw `Symbol.rawValue`).
    /// Teasing with a near-miss shield is not a dopamine hit.
    public var minSymbolRank: Int

    public static let `default` = NearMissConfig(enabled: true, rate: 0.35, minSymbolRank: Symbol.knight.rawValue)
    public static let off       = NearMissConfig(enabled: false, rate: 0, minSymbolRank: 0)
    /// For when you want the machine to torment the player.
    public static let cruel     = NearMissConfig(enabled: true, rate: 0.70, minSymbolRank: Symbol.princess.rawValue)
}

/// A near miss that actually landed, for the UI to point at.
public struct NearMiss: Sendable {
    public let symbol: Symbol
    /// The reel where the run broke.
    public let reel: Int
    /// The row the symbol landed on — always one off `lineRow`.
    public let row: Int
    /// The row it needed to be on.
    public let lineRow: Int
    /// How many reels had already matched. 4 here means the fifth reel missed by
    /// one position, which is the most excruciating outcome the game can produce.
    public let matched: Int
    public let lineIndex: Int
}

/// One winning payline.
public struct LineWin: Equatable, Sendable {
    public let lineIndex: Int      // 0-based index into mode.paylines
    public let symbol: Symbol
    public let count: Int          // how many reels matched, left to right
    public let credits: Int
    /// Grid positions that lit up, as (reel, row). Used to draw the win overlay.
    public let positions: [(reel: Int, row: Int)]

    public static func == (a: LineWin, b: LineWin) -> Bool {
        a.lineIndex == b.lineIndex && a.symbol == b.symbol
            && a.count == b.count && a.credits == b.credits
    }
}

/// Everything one spin produced.
public struct SpinResult: Sendable {
    /// `grid[reel][row]` — 5 columns of 3.
    public let grid: [[Symbol]]
    /// The strip index each reel stopped on. The 3D renderer needs this to know
    /// where to park the cylinder.
    public let stops: [Int]
    public let lineWins: [LineWin]
    public let scatterCount: Int
    public let scatterCredits: Int
    public let freeSpinsAwarded: Int
    public let totalBet: Int
    public let totalWin: Int

    /// Set when this losing spin was dressed up as a tease. Always nil on a win.
    public let nearMiss: NearMiss?

    /// Per-reel flag telling the renderer to stall this reel — spin it longer and
    /// decelerate hard — because something good is still possible when it lands.
    /// This is the other half of the dopamine loop and it's pure presentation: it
    /// reacts to a result already decided, it never influences one.
    public let anticipation: [Bool]

    public var isWin: Bool { totalWin > 0 }

    /// Win size relative to the stake — drives which celebration and which sound
    /// effect fire. Thresholds are the usual industry bands.
    public var tier: WinTier {
        guard totalWin > 0 else { return .none }
        let ratio = Double(totalWin) / Double(max(totalBet, 1))
        if ratio >= 50 { return .jackpot }
        if ratio >= 20 { return .mega }
        if ratio >= 10 { return .big }
        if ratio >= 3  { return .nice }
        return .small
    }
}

public enum WinTier: Int, Sendable {
    case none, small, nice, big, mega, jackpot
}

// MARK: - The machine

/// The slot engine. Holds the RNG stream, so one instance per player session.
public final class SlotMachine: @unchecked Sendable {

    public private(set) var rng: Xoshiro256

    /// A *separate* stream for presentation decisions (whether to tease, which stop
    /// to tease with). Keeping this apart from `rng` is what makes the near-miss
    /// system provably free: no matter how you configure teasing, the game stream
    /// produces the exact same sequence of spins. Share one stream and toggling
    /// near-miss silently reshuffles every future outcome.
    private var presentationRng: Xoshiro256

    private let strips: [[Symbol]]

    /// Changing this mid-session is fine — it only affects how results are scored,
    /// never how they're drawn, so the RNG stream stays continuous.
    /// Three reels or five. Changing this changes the payline set and the
    /// paytable, but not the reel strips, so symbol weightings stay identical.
    public var mode: ReelMode

    public var volatility: Volatility

    /// Presentation-layer tuning. Does not affect the odds; see `NearMissConfig`.
    public var nearMiss: NearMissConfig

    /// A third stream, used only for guaranteed-win bonus spins. Kept separate so
    /// that awarding or spending a bonus spin can never shift the sequence a staked
    /// spin would otherwise have drawn.
    private var bonusRng: Xoshiro256

    /// Guaranteed-win spins the player is still owed.
    ///
    /// These are a gift — awarded for landing the bonus on the reels — and they are
    /// deliberately *not* staked against credits. That separation is the entire
    /// point: the published RTP describes every spin a player pays for, and the
    /// guaranteed wins live only in spins that cost nothing. Nothing here alters the
    /// odds of a paid spin, which is what keeps the paytable in the app honest.
    public private(set) var bonusSpinsRemaining: Int = 0

    /// Number of *staked* spins produced. Bonus spins are excluded so restoring a
    /// session replays the paid stream exactly.
    public private(set) var spinCount: UInt64 = 0

    public init(seed: UInt64? = nil,
                mode: ReelMode = .three,
                volatility: Volatility = .brutal,
                nearMiss: NearMissConfig = .default,
                strips: [[Symbol]] = ReelStrips.strips) {
        var entropy = SystemRandomNumberGenerator()
        let s = seed ?? entropy.next()
        self.rng = Xoshiro256(seed: s)
        // Derived, but far enough away in the state space to be independent.
        self.presentationRng = Xoshiro256(seed: s ^ 0xA5A5_5A5A_DEAD_BEEF)
        self.bonusRng = Xoshiro256(seed: s ^ 0x5EED_B005_7EDD_1234)
        self.mode = mode
        self.volatility = volatility
        self.nearMiss = nearMiss
        self.strips = strips
    }

    /// Grant guaranteed-win spins. Called when the player lands the bonus.
    public func awardBonusSpins(_ n: Int) {
        bonusSpinsRemaining += max(0, n)
    }

    /// Draw a spin that is guaranteed to pay something.
    ///
    /// Implemented by redrawing from the dedicated bonus stream until a paying grid
    /// turns up, capped so a pathological paytable can't hang the game. This is an
    /// explicitly boosted mode, so consuming extra draws is fine — the important part
    /// is that it consumes them from `bonusRng`, leaving the staked stream untouched.
    private func drawGuaranteedWin(betPerLine: Int) -> SpinResult {
        var last: SpinResult?
        for _ in 0 ..< 400 {
            var stops = [Int](repeating: 0, count: mode.reels)
            for reel in 0 ..< mode.reels {
                stops[reel] = Int(bonusRng.next(upperBound: UInt64(strips[reel].count)))
            }
            let result = evaluate(stops: stops, betPerLine: betPerLine)
            last = result
            if result.totalWin > 0 { return result }
        }
        // Every paytable here has paying combinations, so this is unreachable in
        // practice; returning the final draw is better than looping forever.
        return last!
    }

    /// Fast-forwards the stream. Used on launch to restore a persisted session so
    /// the player resumes where they left off instead of restarting the sequence.
    public func advance(to count: UInt64) {
        while spinCount < count {
            for _ in 0 ..< mode.reels { _ = rng.next() }
            spinCount += 1
        }
    }

    /// Spin. `betPerLine` is multiplied by the 20 active lines for the total bet.
    public func spin(betPerLine: Int) -> SpinResult {
        // Bonus spins are drawn from their own stream and never touch `spinCount`,
        // so the staked sequence is identical whether or not any were played.
        if bonusSpinsRemaining > 0 {
            bonusSpinsRemaining -= 1
            return drawGuaranteedWin(betPerLine: betPerLine)
        }

        var stops = [Int](repeating: 0, count: mode.reels)
        for reel in 0 ..< mode.reels {
            stops[reel] = Int(rng.next(upperBound: UInt64(strips[reel].count)))
        }
        spinCount += 1

        let honest = evaluate(stops: stops, betPerLine: betPerLine)

        // Note the presentation stream here, not `rng` — see `presentationRng`.
        guard nearMiss.enabled,
              Double(presentationRng.next(upperBound: 10_000)) / 10_000.0 < nearMiss.rate,
              let teased = findTease(stops: stops, betPerLine: betPerLine, honest: honest)
        else { return honest }

        return teased
    }

    /// Searches for a single-reel nudge that dresses a result up as a visible near
    /// miss without changing what it pays.
    ///
    /// Strategy: find the payline with the longest leading run of a decent symbol,
    /// then try every stop position for the reel where that run broke, looking for
    /// one that parks the needed symbol *one row off* the payline. Longer runs and
    /// more valuable symbols score higher.
    ///
    /// The acceptance test is `totalWin` and `scatterCount` both unchanged — not
    /// "still a loss". That distinction matters: requiring a loss made the best
    /// tease of all impossible, because four-of-a-kind always pays, so a four-match
    /// is never a losing spin. Preserving the payout instead lets a spin that wins
    /// on one line simultaneously show you the king you *just* missed on another.
    private func findTease(stops: [Int], betPerLine: Int, honest: SpinResult) -> SpinResult? {
        let grid = buildGrid(stops: stops)

        // Rank candidate (line, breakReel, symbol) triples by how badly the player
        // will want it.
        struct Candidate { let line: Int; let breakReel: Int; let symbol: Symbol; let run: Int }
        var candidates: [Candidate] = []

        for (lineIndex, line) in mode.paylines.enumerated() {
            let first = grid[0][line[0]]
            guard !first.isScatter else { continue }

            // Resolve what symbol this line is "going for". A leading wild is going
            // for whatever follows it.
            var target = first
            if first.isWild {
                for reel in 1 ..< mode.reels {
                    let s = grid[reel][line[reel]]
                    if s.isWild { continue }
                    if s.isScatter { break }
                    target = s
                    break
                }
            }
            guard !target.isScatter, target.rawValue >= nearMiss.minSymbolRank else { continue }

            var run = 0
            for reel in 0 ..< mode.reels {
                let s = grid[reel][line[reel]]
                if s == target || (s.isWild && !target.isWild) { run += 1 } else { break }
            }
            // Need at least two matched and a reel left to break on.
            guard run >= 2, run < mode.reels else { continue }
            candidates.append(Candidate(line: lineIndex, breakReel: run, symbol: target, run: run))
        }

        guard !candidates.isEmpty else { return nil }
        // Longest run first, then most valuable symbol.
        candidates.sort { $0.run != $1.run ? $0.run > $1.run : $0.symbol.rawValue > $1.symbol.rawValue }

        for c in candidates.prefix(4) {
            let line = mode.paylines[c.line]
            let lineRow = line[c.breakReel]
            let strip = strips[c.breakReel]

            // Which rows count as "one off the line"?
            let adjacentRows = [lineRow - 1, lineRow + 1].filter { $0 >= 0 && $0 < Paylines.rows }
            guard !adjacentRows.isEmpty else { continue }

            // Try stops in a random order so the same tease doesn't recur identically.
            let offset = Int(presentationRng.next(upperBound: UInt64(strip.count)))
            for i in 0 ..< strip.count {
                let candidateStop = (offset + i) % strip.count

                // Does this stop put the target symbol adjacent to the line?
                var landedRow: Int? = nil
                for row in adjacentRows where strip[(candidateStop + row) % strip.count] == c.symbol {
                    landedRow = row
                    break
                }
                guard let row = landedRow else { continue }
                // ...and NOT on the line itself, which would extend the run.
                guard strip[(candidateStop + lineRow) % strip.count] != c.symbol else { continue }

                var trial = stops
                trial[c.breakReel] = candidateStop
                let result = evaluate(stops: trial, betPerLine: betPerLine)

                // The safety net that makes this RTP-neutral: the nudged grid must
                // pay exactly what the honest one paid, and bank the same number of
                // scatters, or we throw it away.
                guard result.totalWin == honest.totalWin,
                      result.scatterCount == honest.scatterCount else { continue }

                return SpinResult(
                    grid: result.grid, stops: result.stops, lineWins: result.lineWins,
                    scatterCount: result.scatterCount, scatterCredits: result.scatterCredits,
                    freeSpinsAwarded: result.freeSpinsAwarded, totalBet: result.totalBet,
                    totalWin: result.totalWin,
                    nearMiss: NearMiss(symbol: c.symbol, reel: c.breakReel, row: row,
                                       lineRow: lineRow, matched: c.run, lineIndex: c.line),
                    anticipation: result.anticipation
                )
            }
        }
        return nil
    }

    /// Pure evaluation, split out from `spin` so tests and the simulator can feed
    /// in fixed stop positions.
    public func evaluate(stops: [Int], betPerLine: Int) -> SpinResult {
        let grid = buildGrid(stops: stops)
        let totalBet = betPerLine * mode.lineCount

        var lineWins: [LineWin] = []
        var lineTotal = 0

        for (lineIndex, line) in mode.paylines.enumerated() {
            guard let win = evaluateLine(grid: grid, line: line,
                                         lineIndex: lineIndex, betPerLine: betPerLine)
            else { continue }
            lineWins.append(win)
            lineTotal += win.credits
        }

        // Scatters pay from anywhere on the grid, so they're counted outside the
        // payline loop and multiply the total bet rather than the line bet.
        var scatterCount = 0
        for reel in 0 ..< mode.reels {
            for row in 0 ..< Paylines.rows where grid[reel][row].isScatter {
                scatterCount += 1
            }
        }
        let scatterCredits = Paytable.scatterPay(count: scatterCount, volatility: volatility, mode: mode) * totalBet
        let freeSpins = Paytable.freeSpins(scatterCount: scatterCount)

        return SpinResult(
            grid: grid,
            stops: stops,
            lineWins: lineWins.sorted { $0.credits > $1.credits },
            scatterCount: scatterCount,
            scatterCredits: scatterCredits,
            freeSpinsAwarded: freeSpins,
            totalBet: totalBet,
            totalWin: lineTotal + scatterCredits,
            nearMiss: nil,
            anticipation: anticipationFlags(grid: grid)
        )
    }

    /// Which reels the renderer should stall on.
    ///
    /// A reel earns anticipation when the reels to its left have already set up
    /// something worth waiting for: either two scatters banked (a third triggers the
    /// bonus) or an unbroken run of three-plus on some payline. The renderer spins
    /// those reels noticeably longer.
    ///
    /// Purely cosmetic — this reads a grid that is already final.
    private func anticipationFlags(grid: [[Symbol]]) -> [Bool] {
        var flags = [Bool](repeating: false, count: mode.reels)

        // Scatter anticipation: count seals reel by reel, flag the reel after the
        // second one lands.
        var seals = 0
        for reel in 0 ..< mode.reels {
            if seals >= 2, reel < mode.reels { flags[reel] = true }
            for row in 0 ..< Paylines.rows where grid[reel][row].isScatter { seals += 1 }
        }

        // Line anticipation: any payline three-deep into a decent symbol.
        for line in mode.paylines {
            let first = grid[0][line[0]]
            guard !first.isScatter else { continue }
            var target = first
            if first.isWild {
                for reel in 1 ..< mode.reels {
                    let s = grid[reel][line[reel]]
                    if s.isWild { continue }
                    if s.isScatter { break }
                    target = s; break
                }
            }
            guard !target.isScatter, target.rawValue >= Symbol.knight.rawValue else { continue }

            var run = 0
            for reel in 0 ..< mode.reels {
                let s = grid[reel][line[reel]]
                if s == target || (s.isWild && !target.isWild) { run += 1 } else { break }
            }
            if run >= 3 && run < mode.reels { flags[run] = true }
        }

        return flags
    }

    /// Reads three consecutive strip positions per reel, wrapping around the end.
    public func buildGrid(stops: [Int]) -> [[Symbol]] {
        (0 ..< mode.reels).map { reel in
            let strip = strips[reel]
            return (0 ..< Paylines.rows).map { row in
                strip[(stops[reel] + row) % strip.count]
            }
        }
    }

    /// Left-to-right matching with wild substitution.
    ///
    /// The subtlety: the crown is both the wild *and* the highest-paying symbol,
    /// so a line starting with crowns has two possible readings — pay it as
    /// crowns, or let the crowns stand in for whatever follows. We evaluate both
    /// and keep whichever is worth more, which is how real machines resolve it.
    private func evaluateLine(grid: [[Symbol]], line: [Int],
                              lineIndex: Int, betPerLine: Int) -> LineWin? {

        func run(matching target: Symbol) -> Int {
            var length = 0
            for reel in 0 ..< mode.reels {
                let s = grid[reel][line[reel]]
                if s == target || (s.isWild && !target.isWild) { length += 1 } else { break }
            }
            return length
        }

        func makeWin(_ symbol: Symbol, _ count: Int) -> LineWin? {
            let pay = Paytable.linePay(symbol, count: count, volatility: volatility, mode: mode) * betPerLine
            guard pay > 0 else { return nil }
            let positions = (0 ..< count).map { (reel: $0, row: line[$0]) }
            return LineWin(lineIndex: lineIndex, symbol: symbol,
                           count: count, credits: pay, positions: positions)
        }

        let first = grid[0][line[0]]
        // A scatter on reel 1 can't start a line win, and there's no wild
        // substitution for it either.
        if first.isScatter { return nil }

        var best: LineWin? = nil

        if first.isWild {
            // Reading A: pure crowns.
            if let w = makeWin(.crown, run(matching: .crown)) { best = w }
            // Reading B: the leading crowns substitute for the first non-crown,
            // non-scatter symbol further along the line.
            for reel in 1 ..< mode.reels {
                let s = grid[reel][line[reel]]
                if s.isWild { continue }
                if s.isScatter { break }
                if let w = makeWin(s, run(matching: s)),
                   w.credits > (best?.credits ?? 0) { best = w }
                break
            }
        } else {
            best = makeWin(first, run(matching: first))
        }

        return best
    }
}
