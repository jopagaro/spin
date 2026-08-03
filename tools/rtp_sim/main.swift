//
//  main.swift — RTP / volatility simulator
//
//  Compiles SlotMath.swift (the same file the app ships) and hammers each
//  volatility profile with millions of spins to measure what it actually returns.
//  Run it after any change to the reel strips or paytable.
//
//  Build & run:
//    swiftc -O ios/RoyalSpin/RoyalSpin/Core/SlotMath.swift tools/rtp_sim/main.swift -o /tmp/rtp_sim
//    /tmp/rtp_sim 5000000
//

import Foundation

let spins = CommandLine.arguments.count > 1
    ? (Int(CommandLine.arguments[1]) ?? 1_000_000)
    : 1_000_000

let betPerLine = 1
let totalBet = betPerLine * Paylines.count

struct Report {
    let volatility: Volatility
    let rtp: Double
    let hitFrequency: Double
    let biggestWin: Int
    let scatterRate: Double
    let tierCounts: [Int]
    let symbolCredits: [Symbol: Int]
    let scatterCredits: Int
    let totalReturned: Int
    /// Standard deviation of per-spin return, in units of the bet. This *is*
    /// volatility as the industry measures it — the profile names are marketing,
    /// this number is the fact.
    let sigma: Double
    /// How many spins until a median player is down to nothing, starting from 100×
    /// the bet. Simulated separately, because it's the number a player actually feels.
    let medianSpinsToBust: Int
    /// Share of all spins presented as a near miss.
    let teaseRate: Double
    /// Share of all spins that missed on the *fifth* reel — the worst kind.
    let brutalTeaseRate: Double
    /// Share of spins where at least one reel stalls dramatically.
    let anticipationRate: Double
}

func simulate(_ volatility: Volatility, nearMiss: NearMissConfig = .default) -> Report {
    // Fixed seed per profile so the numbers are reproducible run to run.
    let machine = SlotMachine(seed: 0xC0FFEE_D15EA5E, volatility: volatility, nearMiss: nearMiss)

    var returned = 0
    var hits = 0
    var scatterHits = 0
    var biggestWin = 0
    var tierCounts = [Int](repeating: 0, count: 6)
    var symbolCredits = [Symbol: Int]()
    var scatterCredits = 0
    var sumSq = 0.0
    var teases = 0
    var brutalTeases = 0
    var anticipationSpins = 0

    for _ in 0 ..< spins {
        let r = machine.spin(betPerLine: betPerLine)
        if let nm = r.nearMiss {
            teases += 1
            // Three matched and the fourth one row off is the deepest tease that's
            // reachable while preserving payout — four-of-a-kind always pays, so a
            // four-match is by definition already a win.
            if nm.matched >= 3 { brutalTeases += 1 }
        }
        if r.anticipation.contains(true) { anticipationSpins += 1 }
        returned += r.totalWin
        if r.isWin { hits += 1 }
        if r.scatterCount >= 3 { scatterHits += 1 }
        biggestWin = max(biggestWin, r.totalWin)
        tierCounts[r.tier.rawValue] += 1
        for w in r.lineWins { symbolCredits[w.symbol, default: 0] += w.credits }
        scatterCredits += r.scatterCredits
        let x = Double(r.totalWin) / Double(totalBet)
        sumSq += x * x
    }

    let wagered = spins * totalBet
    let mean = Double(returned) / Double(wagered)
    let variance = sumSq / Double(spins) - mean * mean

    // Bankroll survival: 2,000 independent players, 100× bet each, spin until broke.
    var bustSpins: [Int] = []
    for player in 0 ..< 2_000 {
        let m = SlotMachine(seed: UInt64(0xBA5E_BA11 &+ UInt64(player)),
                            volatility: volatility, nearMiss: nearMiss)
        var balance = 100 * totalBet
        var n = 0
        while balance >= totalBet && n < 100_000 {
            balance -= totalBet
            balance += m.spin(betPerLine: betPerLine).totalWin
            n += 1
        }
        bustSpins.append(n)
    }
    bustSpins.sort()

    return Report(
        volatility: volatility,
        rtp: 100.0 * mean,
        hitFrequency: 100.0 * Double(hits) / Double(spins),
        biggestWin: biggestWin,
        scatterRate: 100.0 * Double(scatterHits) / Double(spins),
        tierCounts: tierCounts,
        symbolCredits: symbolCredits,
        scatterCredits: scatterCredits,
        totalReturned: returned,
        sigma: variance.squareRoot(),
        medianSpinsToBust: bustSpins[bustSpins.count / 2],
        teaseRate: 100.0 * Double(teases) / Double(spins),
        brutalTeaseRate: 100.0 * Double(brutalTeases) / Double(spins),
        anticipationRate: 100.0 * Double(anticipationSpins) / Double(spins)
    )
}

print("""

╔═══════════════════════════════════════════════════════════════════════════╗
║  ROYAL SPIN — reel math report                                            ║
╚═══════════════════════════════════════════════════════════════════════════╝

  \(spins.formatted()) spins per profile · \(totalBet) credits/spin (\(Paylines.count) lines × \(betPerLine))
""")

let start = Date()
let reports = Volatility.allCases.map { simulate($0) }
let elapsed = Date().timeIntervalSince(start)

// ── Comparison table ────────────────────────────────────────────────────────
print("""

  ┌──────────────┬─────────┬───────────┬──────────┬───────────┬──────────────┐
  │ profile      │   RTP   │ hit freq  │ 1 win in │  σ (vol)  │ median spins │
  │              │         │           │  N spins │           │   to broke   │
  ├──────────────┼─────────┼───────────┼──────────┼───────────┼──────────────┤
""")
for r in reports {
    let name = r.volatility.displayName.padding(toLength: 12, withPad: " ", startingAt: 0)
    print(String(format: "  │ %@ │ %6.2f%% │  %6.2f%%  │  %6.1f  │  %7.2f  │    %6d    │",
                 name, r.rtp, r.hitFrequency, 100.0 / max(r.hitFrequency, 0.001),
                 r.sigma, r.medianSpinsToBust))
}
print("  └──────────────┴─────────┴───────────┴──────────┴───────────┴──────────────┘")

print("""

  σ is the standard deviation of per-spin return in units of the bet — the industry's
  actual definition of volatility. Higher σ = wilder swings. "Median spins to broke"
  starts 2,000 simulated players at 100× the bet and counts spins until they can't
  cover another one.
""")

// ── Per-profile detail ──────────────────────────────────────────────────────
let tierNames = ["no win", "small (<3×)", "nice (3-10×)", "big (10-20×)", "mega (20-50×)", "JACKPOT (50×+)"]

for r in reports {
    print("\n  ══ \(r.volatility.displayName.uppercased()) ══ \(r.volatility.blurb)")
    print("     biggest win seen: \(r.biggestWin.formatted()) credits (\(r.biggestWin / totalBet)× bet)   ·   3+ scatters: 1 in \(String(format: "%.0f", 100.0 / max(r.scatterRate, 0.0001))) spins")
    print(String(format: "     near miss shown on %.1f%% of spins (%.2f%% of them 3-deep) · a reel stalls on %.1f%%",
                 r.teaseRate, r.brutalTeaseRate, r.anticipationRate))
    print("")
    for (i, name) in tierNames.enumerated() {
        let share = 100.0 * Double(r.tierCounts[i]) / Double(spins)
        let bar = String(repeating: "█", count: max(0, Int(share.rounded())))
        print(String(format: "     %-16@ %6.3f%%  %@", name as NSString, share, bar as NSString))
    }
    // Where the payout actually comes from.
    let ordered = Symbol.allCases
        .map { ($0, r.symbolCredits[$0] ?? 0) }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    print("")
    var line = "     payout mix: "
    for (s, c) in ordered.prefix(5) {
        line += "\(s.displayName) \(String(format: "%.0f%%", 100.0 * Double(c) / Double(max(r.totalReturned, 1))))  "
    }
    line += "Seal \(String(format: "%.0f%%", 100.0 * Double(r.scatterCredits) / Double(max(r.totalReturned, 1))))"
    print(line)
}

// ── Near-miss neutrality proof ──────────────────────────────────────────────
// Run each profile with teasing fully off and fully cruel. Every payout statistic
// must come out identical to the digit — if it doesn't, the tease is cheating.
print("\n  ══ NEAR-MISS NEUTRALITY CHECK ══")
print("     Same seed, teasing off vs. cruel. RTP must match exactly.\n")
print("     ┌──────────────┬────────────┬────────────┬────────────┬──────────┐")
print("     │ profile      │  RTP  off  │ RTP cruel  │  Δ         │ verdict  │")
print("     ├──────────────┼────────────┼────────────┼────────────┼──────────┤")
var allNeutral = true
for v in Volatility.allCases {
    let off   = simulate(v, nearMiss: .off)
    let cruel = simulate(v, nearMiss: .cruel)
    let delta = abs(off.rtp - cruel.rtp)
    let ok = delta < 1e-9 && off.hitFrequency == cruel.hitFrequency
    if !ok { allNeutral = false }
    print(String(format: "     │ %@ │ %8.4f%% │ %8.4f%% │ %10.2e │ %@ │",
                 v.displayName.padding(toLength: 12, withPad: " ", startingAt: 0),
                 off.rtp, cruel.rtp, delta,
                 (ok ? "  PASS  " : "  FAIL  ")))
}
print("     └──────────────┴────────────┴────────────┴────────────┴──────────┘")
print(allNeutral
      ? "     ✓ Teasing changes which losing grid you see, never whether you won."
      : "     ✗ REGRESSION: the tease is altering payouts. Fix findTease().")

// ── RNG sanity ──────────────────────────────────────────────────────────────
print("\n  ══ RNG UNIFORMITY ══ (reel 1 stop distribution)")
var probe = Xoshiro256(seed: 12345)
let stripLen = ReelStrips.strips[0].count
var buckets = [Int](repeating: 0, count: stripLen)
let probes = 2_000_000
for _ in 0 ..< probes { buckets[Int(probe.next(upperBound: UInt64(stripLen)))] += 1 }
let expected = Double(probes) / Double(stripLen)
let chi2 = buckets.reduce(0.0) { $0 + pow(Double($1) - expected, 2) / expected }
print("     χ² = \(String(format: "%.1f", chi2)) with \(stripLen - 1) df — expect ≈ \(stripLen - 1); a much larger value means a biased RNG")

print("\n  ══ REEL STRIPS ══")
for (i, strip) in ReelStrips.strips.enumerated() {
    var counts = [Symbol: Int]()
    for s in strip { counts[s, default: 0] += 1 }
    let summary = Symbol.allCases.compactMap { s -> String? in
        guard let c = counts[s] else { return nil }
        return "\(s.displayName.prefix(3)):\(c)"
    }.joined(separator: " ")
    print("     reel \(i + 1) (\(strip.count) stops)  \(summary)")
}

print("\n  simulated in \(String(format: "%.1fs", elapsed))\n")
