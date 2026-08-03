# Royal Spin — the math

Everything here is **measured**, not estimated. Regenerate with:

```bash
swiftc -O ios/RoyalSpin/RoyalSpin/Core/SlotMath.swift tools/rtp_sim/main.swift -o /tmp/rtp_sim && /tmp/rtp_sim 5000000
```

---

## How real slot math works

Three numbers describe a slot machine, and conflating them is the classic beginner
mistake:

| | what it means | typical real values |
|---|---|---|
| **RTP** | fraction of total wagers returned over millions of spins | 85–88% (Vegas penny), 94–97% (online) |
| **Hit frequency** | fraction of *spins* that pay anything at all | 25–45% |
| **Volatility (σ)** | standard deviation of per-spin return, in units of the bet | 2 (low) → 10+ (high) |

**RTP and hit frequency are independent.** Our own numbers prove it: `Classic` and
`Royal Ruin` return an identical 89.86%, but Classic pays on 1 spin in 4.7 and Royal
Ruin on 1 in 11.4. Same money out, totally different experience. Royal Ruin
concentrates the same payout into rarer, far larger wins — σ is 7.29 against
Classic's 3.88.

So "make it barely ever hit" is a request for **high volatility**, not low RTP.

### The Telnaes patent — why any of this is possible

Before 1984, a slot's odds were bounded by physical reel positions: three reels of 20
symbols is 8,000 combinations, so the top jackpot could never exceed a few thousand
to one. Inge Telnaes' US Patent 4,448,419 introduced the **virtual reel** — a table in
software with far more stops than the physical reel has positions, many virtual stops
mapping onto the same physical symbol. IGT bought it in 1988 and licensed it industry-wide.

That decoupling is what lets a machine show three reels while offering million-to-one
odds. Our `ReelStrips` are exactly this: 56-stop virtual strips per reel, weighted so
the King appears 4 times on reel 1 but only twice on reel 5.

### Near miss

The same weighting can be pointed at the space *next to* a jackpot symbol, so the
player repeatedly sees the payline miss by one position. It's the most psychologically
potent trick in slot design, and for money gambling it's regulated for that reason.

**We implement it differently** — see below — precisely so it can't touch the odds.

---

## Measured results

5,000,000 spins per profile, 20 credits/spin (20 lines × 1).

| profile | RTP | hit freq | 1 win in | σ | median spins to broke\* |
|---|---|---|---|---|---|
| Gentle | 94.85% | 35.32% | 2.8 | 2.76 | 1161 |
| Classic | 89.86% | 21.49% | 4.7 | 3.88 | 586 |
| **Royal Ruin** (default) | **89.86%** | **8.75%** | **11.4** | **7.29** | **360** |

\* 2,000 simulated players starting with 100× the bet, spinning until they can't cover
another spin.

Biggest win observed in 1M spins: Gentle 193× bet · Classic 335× · Royal Ruin **1358×**.

### What makes Royal Ruin brutal

One lever does most of the work: **nothing below Princess pays for three of a kind.**
Three-of-a-kind on a common low symbol is what generates the flood of trivial wins that
drags hit frequency into the 30s. Delete those and hit frequency collapses to 8.75%
while the payout redistributes into four- and five-of-a-kind hits.

### Win distribution (Royal Ruin)

```
no win           91.2%
small   (<3×)     3.4%
nice    (3-10×)   2.4%
big     (10-20×)  1.7%
mega    (20-50×)  1.0%
JACKPOT (50×+)    0.24%
```

Free spins (3+ Royal Seals): 1 in 97 spins, all profiles.

---

## The near-miss system, and why it's honest

Configured by `NearMissConfig`. Default: on, 35% of eligible spins, only teasing with
Knight-or-better symbols.

**Implementation.** The RNG draws a completely honest result. We then look for a payline
with a leading run of 2–4 matching symbols and try alternate stop positions for the reel
where the run broke, searching for one that parks the needed symbol *one row off* the
payline. The nudged grid is accepted **only if `totalWin` and `scatterCount` are both
bit-identical to the honest result.**

Two design details make it airtight:

1. **A separate RNG stream** (`presentationRng`) drives the tease decisions. Share one
   stream with the game and merely toggling near-miss would silently reshuffle every
   future spin — which is exactly the bug the neutrality check caught during development.
2. **Preserve payout, don't require a loss.** Requiring "still a loss" seems safer but
   makes the best tease impossible: four-of-a-kind always pays, so a four-match is never
   a losing spin. Preserving the payout instead lets a spin that wins on one line also
   show you the King you just missed on another.

**Verified every run:**

```
┌──────────────┬────────────┬────────────┬────────────┬──────────┐
│ profile      │  RTP  off  │ RTP cruel  │  Δ         │ verdict  │
├──────────────┼────────────┼────────────┼────────────┼──────────┤
│ Gentle       │  94.8544% │  94.8544% │   0.00e+00 │   PASS   │
│ Classic      │  89.8637% │  89.8637% │   0.00e+00 │   PASS   │
│ Royal Ruin   │  89.8573% │  89.8573% │   0.00e+00 │   PASS   │
└──────────────┴────────────┴────────────┴────────────┴──────────┘
```

Δ is exactly zero, not merely small. Teasing changes *which* losing grid you see, never
whether you won.

Observed rates on Royal Ruin: a near miss is shown on **11.5%** of spins, of which 3.6%
are three-deep. A reel stalls dramatically on **23.2%** of spins.

### Anticipation

Separate from near miss, and also pure presentation. `SpinResult.anticipation` flags
reels the renderer should spin longer and decelerate hard into. A reel earns it when the
reels to its left have already banked two scatters, or an unbroken run of 3+ on a
payline. It reads a grid that is already final — it cannot influence an outcome.

---

## RNG

**xoshiro256\*\*** with SplitMix64 seeding, seeded from the system CSPRNG. Shipped
rather than using `Int.random(in:)` so a bug report can be replayed exactly from a seed,
and so a stdlib change can't silently alter the paytable.

Bounded draws use **rejection sampling**, not `next() % n`. The naive modulo is biased
toward small values whenever `n` doesn't divide 2^64 — on a 56-stop strip that would
quietly bend the paytable toward whatever sits at low indices.

Uniformity check, 2M draws over 56 buckets: **χ² = 42.9 against 55 df** (expect ≈ 55).
Clean.

---

## Paylines

20 fixed lines on a 5×3 grid, evaluated left-to-right from reel 1. Definitions in
`Paylines.all`.

**Wild resolution.** The Crown is both the wild *and* the top-paying line symbol, so a
line beginning with crowns has two valid readings — pay it as crowns, or let the crowns
substitute for whatever follows. Both are evaluated and the higher-paying one wins,
which is how commercial machines resolve it.

Scatters (Royal Seal) pay from anywhere, ignore paylines, and multiply *total* bet
rather than line bet.
