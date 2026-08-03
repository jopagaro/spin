package com.royalspin.core

/**
 * SlotMath.kt
 *
 * Line-for-line port of ios/RoyalSpin/RoyalSpin/Core/SlotMath.swift.
 *
 * The two files are the single source of truth for the game's odds and MUST stay in
 * step: same symbols, same reel strips, same paytable, same RNG algorithm. Change
 * one, change the other, then re-run both simulators and check the RTP still matches.
 *
 * Deliberately free of Android dependencies so it can be unit-tested on the JVM.
 */

// ─────────────────────────────────────────────────────────────────── Symbols ──

/**
 * The royal court. Ordinal values are the reel-strip encoding and the art index —
 * do not reorder casually.
 */
enum class Symbol(val id: Int, val assetName: String, val displayName: String) {
    SHIELD(0, "shield", "Shield"),
    CHALICE(1, "chalice", "Chalice"),
    SCEPTRE(2, "sceptre", "Sceptre"),
    JOKER(3, "joker", "Joker"),
    KNIGHT(4, "knight", "Knight"),
    PRINCESS(5, "princess", "Princess"),
    PRINCE(6, "prince", "Prince"),
    QUEEN(7, "queen", "Queen"),
    KING(8, "king", "King"),
    CROWN(9, "crown", "Crown"),
    ROYAL_SEAL(10, "royal_seal", "Royal Seal");

    val isWild: Boolean get() = this == CROWN
    val isScatter: Boolean get() = this == ROYAL_SEAL

    /** Drawable name, matching what tools/install_art.py writes into res/drawable-*. */
    val drawableName: String get() = "sym_$assetName"

    companion object {
        val all: List<Symbol> = entries
    }
}

// ──────────────────────────────────────────────────────────────── Volatility ──

/**
 * How the game feels. RTP and hit frequency are *independent* knobs; conflating them
 * is the classic slot-design mistake.
 *
 * The lever doing most of the work is the three-of-a-kind row: on [BRUTAL] the low
 * symbols pay nothing for three in a row, which deletes the flood of trivial wins
 * that otherwise drives hit frequency into the 30s.
 *
 * Measured figures live in design/math.md.
 */
enum class Volatility(val displayName: String, val blurb: String) {
    GENTLE("Gentle", "Frequent small wins. Your balance drifts."),
    CLASSIC("Classic", "A real casino floor machine."),
    BRUTAL("Royal Ruin", "Almost never pays. When it does, you'll know.");
}

// ────────────────────────────────────────────────────────────────── Paytable ──

object Paytable {

    /**
     * Line pays as a multiple of the *line bet*, indexed by match length:
     * slot 0 = three of a kind, 1 = four, 2 = five.
     *
     * A zero in slot 0 means that symbol doesn't pay for three in a row — the
     * primary hit-frequency control, not a bug.
     */
    private fun table(symbol: Symbol, v: Volatility): IntArray = when (v) {

        // ~95% RTP, ~35% hit frequency. Everything pays from three.
        Volatility.GENTLE -> when (symbol) {
            Symbol.SHIELD -> intArrayOf(8, 30, 90)
            Symbol.CHALICE -> intArrayOf(8, 35, 110)
            Symbol.SCEPTRE -> intArrayOf(11, 45, 140)
            Symbol.JOKER -> intArrayOf(15, 60, 180)
            Symbol.KNIGHT -> intArrayOf(18, 70, 230)
            Symbol.PRINCESS -> intArrayOf(22, 110, 350)
            Symbol.PRINCE -> intArrayOf(28, 140, 450)
            Symbol.QUEEN -> intArrayOf(45, 220, 750)
            Symbol.KING -> intArrayOf(60, 300, 1100)
            Symbol.CROWN -> intArrayOf(80, 600, 3000)
            Symbol.ROYAL_SEAL -> intArrayOf(0, 0, 0)
        }

        // Lows need four. Mids still pay from three, but thinly.
        Volatility.CLASSIC -> when (symbol) {
            Symbol.SHIELD -> intArrayOf(0, 36, 140)
            Symbol.CHALICE -> intArrayOf(0, 40, 155)
            Symbol.SCEPTRE -> intArrayOf(0, 50, 185)
            Symbol.JOKER -> intArrayOf(8, 72, 255)
            Symbol.KNIGHT -> intArrayOf(10, 90, 330)
            Symbol.PRINCESS -> intArrayOf(17, 145, 500)
            Symbol.PRINCE -> intArrayOf(22, 200, 680)
            Symbol.QUEEN -> intArrayOf(35, 345, 1280)
            Symbol.KING -> intArrayOf(48, 500, 2000)
            Symbol.CROWN -> intArrayOf(90, 1000, 5500)
            Symbol.ROYAL_SEAL -> intArrayOf(0, 0, 0)
        }

        // Nothing below Princess pays for three. Almost every spin is a loss; the
        // payout is concentrated into rare four- and five-of-a-kind hits.
        Volatility.BRUTAL -> when (symbol) {
            Symbol.SHIELD -> intArrayOf(0, 30, 200)
            Symbol.CHALICE -> intArrayOf(0, 35, 240)
            Symbol.SCEPTRE -> intArrayOf(0, 45, 300)
            Symbol.JOKER -> intArrayOf(0, 70, 450)
            Symbol.KNIGHT -> intArrayOf(0, 90, 600)
            Symbol.PRINCESS -> intArrayOf(0, 150, 1000)
            Symbol.PRINCE -> intArrayOf(0, 220, 1500)
            Symbol.QUEEN -> intArrayOf(0, 400, 3000)
            Symbol.KING -> intArrayOf(0, 650, 5000)
            Symbol.CROWN -> intArrayOf(0, 1500, 25000)
            Symbol.ROYAL_SEAL -> intArrayOf(0, 0, 0)
        }
    }

    fun linePay(symbol: Symbol, count: Int, volatility: Volatility): Int {
        if (count < 3 || count > 5) return 0
        return table(symbol, volatility)[count - 3]
    }

    /**
     * Scatter pays as a multiple of the *total bet* (not the line bet), because
     * scatters ignore paylines and land anywhere on the grid.
     */
    fun scatterPay(count: Int, volatility: Volatility): Int = when (volatility) {
        Volatility.GENTLE -> when (count) { 3 -> 3; 4 -> 15; 5 -> 100; else -> 0 }
        Volatility.CLASSIC -> when (count) { 3 -> 2; 4 -> 20; 5 -> 200; else -> 0 }
        // Three seals award spins but no cash.
        Volatility.BRUTAL -> when (count) { 4 -> 25; 5 -> 500; else -> 0 }
    }

    /**
     * Free spins awarded by a scatter hit. Identical across profiles — the bonus is
     * the reward for surviving, so it shouldn't get rarer as the game gets harsher.
     */
    fun freeSpins(scatterCount: Int): Int = when (scatterCount) {
        3 -> 8; 4 -> 12; 5 -> 20; else -> 0
    }
}

// ────────────────────────────────────────────────────────────────── Paylines ──

object Paylines {
    const val ROWS = 3
    const val REELS = 5

    /**
     * 20 fixed paylines. Each entry is the row index (0 = top, 2 = bottom) the line
     * occupies on each of the five reels, left to right.
     */
    val all: List<IntArray> = listOf(
        intArrayOf(1, 1, 1, 1, 1),  //  1  straight middle
        intArrayOf(0, 0, 0, 0, 0),  //  2  straight top
        intArrayOf(2, 2, 2, 2, 2),  //  3  straight bottom
        intArrayOf(0, 1, 2, 1, 0),  //  4  V
        intArrayOf(2, 1, 0, 1, 2),  //  5  inverted V
        intArrayOf(0, 0, 1, 2, 2),  //  6
        intArrayOf(2, 2, 1, 0, 0),  //  7
        intArrayOf(1, 2, 2, 2, 1),  //  8
        intArrayOf(1, 0, 0, 0, 1),  //  9
        intArrayOf(1, 2, 1, 0, 1),  // 10
        intArrayOf(1, 0, 1, 2, 1),  // 11
        intArrayOf(0, 1, 1, 1, 0),  // 12
        intArrayOf(2, 1, 1, 1, 2),  // 13
        intArrayOf(0, 1, 0, 1, 0),  // 14  zigzag top
        intArrayOf(2, 1, 2, 1, 2),  // 15  zigzag bottom
        intArrayOf(1, 1, 0, 1, 1),  // 16
        intArrayOf(1, 1, 2, 1, 1),  // 17
        intArrayOf(0, 0, 1, 0, 0),  // 18
        intArrayOf(2, 2, 1, 2, 2),  // 19
        intArrayOf(0, 2, 0, 2, 0),  // 20  full zigzag
    )

    val count: Int get() = all.size
}

// ─────────────────────────────────────────────────────────────────────── RNG ──

/**
 * xoshiro256** — small, fast and statistically solid for game use.
 *
 * Shipped rather than using [kotlin.random.Random] so a bug report can be replayed
 * exactly from a seed, and so a stdlib change can't silently alter the paytable.
 * Not cryptographic, which is fine — nothing here is worth money. The *seed* comes
 * from the platform CSPRNG, so two installs never share a stream.
 */
class Xoshiro256(seed: Long) {

    private var s0: Long
    private var s1: Long
    private var s2: Long
    private var s3: Long

    init {
        // SplitMix64 spreads a single seed value across all four words.
        var z = seed
        fun splitmix(): Long {
            z += -0x61c8864680b583ebL          // 0x9E3779B97F4A7C15
            var x = z
            x = (x xor (x ushr 30)) * -0x40a7b892e31b1a47L   // 0xBF58476D1CE4E5B9
            x = (x xor (x ushr 27)) * -0x6b2fb644ecceee15L   // 0x94D049BB133111EB
            return x xor (x ushr 31)
        }
        s0 = splitmix(); s1 = splitmix(); s2 = splitmix(); s3 = splitmix()
        // A zero state is a fixed point for xoshiro; make it impossible.
        if (s0 == 0L && s1 == 0L && s2 == 0L && s3 == 0L) s0 = -0x61c8864680b583ebL
    }

    private fun rotl(x: Long, k: Int): Long = (x shl k) or (x ushr (64 - k))

    fun next(): Long {
        val result = rotl(s1 * 5, 7) * 9
        val t = s1 shl 17
        s2 = s2 xor s0
        s3 = s3 xor s1
        s1 = s1 xor s2
        s0 = s0 xor s3
        s2 = s2 xor t
        s3 = rotl(s3, 45)
        return result
    }

    /**
     * Unbiased bounded draw via rejection sampling.
     *
     * The naive `next() % n` is skewed toward small values whenever n doesn't divide
     * 2^64, which on a 56-stop reel strip would quietly bend the paytable. Arithmetic
     * is done unsigned — Kotlin's Long is signed, so the comparisons below use
     * [java.lang.Long.compareUnsigned] semantics via `toULong`.
     */
    fun next(upperBound: Int): Int {
        require(upperBound > 0)
        val bound = upperBound.toULong()
        val threshold = ((0uL - bound) % bound)
        while (true) {
            val r = next().toULong()
            if (r >= threshold) return (r % bound).toInt()
        }
    }
}

// ───────────────────────────────────────────────────────────────── Reel strips ──

object ReelStrips {

    /**
     * Symbol counts per reel. Reel 1 is the most generous and each subsequent reel
     * gets stingier with the high symbols — this is what makes a game feel like it
     * "almost" hit, because the left of a line fills in far more often than the right.
     * Changing any number here changes the RTP.
     */
    private val composition: List<Map<Symbol, Int>> = listOf(
        mapOf(Symbol.KING to 4, Symbol.QUEEN to 4, Symbol.PRINCE to 5, Symbol.PRINCESS to 5,
              Symbol.KNIGHT to 6, Symbol.JOKER to 6, Symbol.SCEPTRE to 7, Symbol.CHALICE to 7,
              Symbol.SHIELD to 8, Symbol.CROWN to 2, Symbol.ROYAL_SEAL to 2),
        mapOf(Symbol.KING to 3, Symbol.QUEEN to 4, Symbol.PRINCE to 4, Symbol.PRINCESS to 5,
              Symbol.KNIGHT to 6, Symbol.JOKER to 6, Symbol.SCEPTRE to 7, Symbol.CHALICE to 8,
              Symbol.SHIELD to 8, Symbol.CROWN to 3, Symbol.ROYAL_SEAL to 2),
        mapOf(Symbol.KING to 3, Symbol.QUEEN to 3, Symbol.PRINCE to 4, Symbol.PRINCESS to 4,
              Symbol.KNIGHT to 6, Symbol.JOKER to 6, Symbol.SCEPTRE to 8, Symbol.CHALICE to 8,
              Symbol.SHIELD to 9, Symbol.CROWN to 3, Symbol.ROYAL_SEAL to 2),
        mapOf(Symbol.KING to 2, Symbol.QUEEN to 3, Symbol.PRINCE to 4, Symbol.PRINCESS to 4,
              Symbol.KNIGHT to 6, Symbol.JOKER to 7, Symbol.SCEPTRE to 8, Symbol.CHALICE to 8,
              Symbol.SHIELD to 9, Symbol.CROWN to 3, Symbol.ROYAL_SEAL to 2),
        mapOf(Symbol.KING to 2, Symbol.QUEEN to 2, Symbol.PRINCE to 3, Symbol.PRINCESS to 4,
              Symbol.KNIGHT to 6, Symbol.JOKER to 7, Symbol.SCEPTRE to 8, Symbol.CHALICE to 9,
              Symbol.SHIELD to 10, Symbol.CROWN to 3, Symbol.ROYAL_SEAL to 2),
    )

    /**
     * The physical strips, built once with the same deterministic seeds as the Swift
     * side so both platforms produce byte-identical strips.
     */
    val strips: List<List<Symbol>> = composition.mapIndexed { index, counts ->
        buildStrip(counts, -0x61c8864680b583ebL + index)
    }

    private fun buildStrip(counts: Map<Symbol, Int>, seed: Long): List<Symbol> {
        val pool = ArrayList<Symbol>()
        // Iterate the enum, not the map, so construction is stable across runs.
        for (symbol in Symbol.all) repeat(counts[symbol] ?: 0) { pool.add(symbol) }

        val rng = Xoshiro256(seed)
        // Fisher–Yates with our own PRNG so a stdlib shuffle change can never
        // silently alter the paytable.
        for (i in pool.size - 1 downTo 1) {
            val j = rng.next(i + 1)
            val tmp = pool[i]; pool[i] = pool[j]; pool[j] = tmp
        }
        return declump(pool, rng)
    }

    /**
     * Break up runs of 3+ identical symbols, which look broken scrolling past.
     * Purely cosmetic: it permutes the strip, so symbol counts — and therefore the
     * odds — are untouched.
     */
    private fun declump(input: MutableList<Symbol>, rng: Xoshiro256): List<Symbol> {
        val n = input.size
        repeat(8) {   // a few passes is plenty; bail rather than loop forever
            var clean = true
            for (i in 0 until n) {
                val a = input[i]
                val b = input[(i + 1) % n]
                val c = input[(i + 2) % n]
                if (a != b || b != c) continue
                clean = false
                val idx = (i + 1) % n
                repeat(32) {
                    val j = rng.next(n)
                    if (j != idx) {
                        val tmp = input[idx]; input[idx] = input[j]; input[j] = tmp
                        return@repeat
                    }
                }
            }
            if (clean) return input
        }
        return input
    }
}

// ─────────────────────────────────────────────────── Near miss & anticipation ──

/**
 * Tuning for the "so close" effect.
 *
 * Implemented post hoc rather than by bending the reel strips, so it provably cannot
 * change the odds: the RNG draws an honest result, and we may re-roll a single reel
 * only if the nudged grid pays *exactly* what the original did. See the Swift file
 * and design/math.md for the full argument.
 */
data class NearMissConfig(
    val enabled: Boolean,
    /** Fraction of eligible spins that get dressed up as a tease, 0..1. */
    val rate: Double,
    /** Only tease with symbols at least this valuable (Symbol.id). */
    val minSymbolRank: Int,
) {
    companion object {
        val DEFAULT = NearMissConfig(true, 0.35, Symbol.KNIGHT.id)
        val OFF = NearMissConfig(false, 0.0, 0)
        val CRUEL = NearMissConfig(true, 0.70, Symbol.PRINCESS.id)
    }
}

/** A near miss that actually landed, for the UI to point at. */
data class NearMiss(
    val symbol: Symbol,
    /** The reel where the run broke. */
    val reel: Int,
    /** The row the symbol landed on — always one off [lineRow]. */
    val row: Int,
    val lineRow: Int,
    /** How many reels had already matched. */
    val matched: Int,
    val lineIndex: Int,
)

// ────────────────────────────────────────────────────────────── Spin results ──

data class LineWin(
    val lineIndex: Int,
    val symbol: Symbol,
    val count: Int,
    val credits: Int,
    /** Grid positions that lit up, as (reel, row). */
    val positions: List<Pair<Int, Int>>,
)

enum class WinTier { NONE, SMALL, NICE, BIG, MEGA, JACKPOT }

data class SpinResult(
    /** `grid[reel][row]` — 5 columns of 3. */
    val grid: List<List<Symbol>>,
    /** Strip index each reel stopped on; the renderer needs this to park the reel. */
    val stops: IntArray,
    val lineWins: List<LineWin>,
    val scatterCount: Int,
    val scatterCredits: Int,
    val freeSpinsAwarded: Int,
    val totalBet: Int,
    val totalWin: Int,
    /** Set when this spin was dressed up as a tease. */
    val nearMiss: NearMiss? = null,
    /** Per-reel flag telling the renderer to stall this reel dramatically. */
    val anticipation: BooleanArray = BooleanArray(Paylines.REELS),
) {
    val isWin: Boolean get() = totalWin > 0

    /** Win size relative to the stake — drives the celebration and the sound. */
    val tier: WinTier
        get() {
            if (totalWin <= 0) return WinTier.NONE
            val ratio = totalWin.toDouble() / maxOf(totalBet, 1)
            return when {
                ratio >= 50 -> WinTier.JACKPOT
                ratio >= 20 -> WinTier.MEGA
                ratio >= 10 -> WinTier.BIG
                ratio >= 3 -> WinTier.NICE
                else -> WinTier.SMALL
            }
        }

    // Arrays in a data class need hand-written equality.
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SpinResult) return false
        return grid == other.grid && stops.contentEquals(other.stops) &&
            lineWins == other.lineWins && totalWin == other.totalWin &&
            totalBet == other.totalBet && scatterCount == other.scatterCount
    }

    override fun hashCode(): Int =
        31 * (31 * grid.hashCode() + stops.contentHashCode()) + totalWin
}

// ─────────────────────────────────────────────────────────────── The machine ──

/** The slot engine. Holds the RNG stream, so one instance per player session. */
class SlotMachine(
    seed: Long,
    var volatility: Volatility = Volatility.BRUTAL,
    var nearMiss: NearMissConfig = NearMissConfig.DEFAULT,
    private val strips: List<List<Symbol>> = ReelStrips.strips,
) {

    private val rng = Xoshiro256(seed)

    /**
     * A *separate* stream for presentation decisions. Keeping this apart from [rng]
     * is what makes the near-miss system provably free: however it's configured, the
     * game stream produces the same sequence of spins. Share one stream and merely
     * toggling near-miss silently reshuffles every future outcome.
     */
    private val presentationRng = Xoshiro256(seed xor -0x5a5aa5a521125411L)

    var spinCount: Long = 0L
        private set

    /** Fast-forward the stream so a returning player resumes where they left off. */
    fun advanceTo(count: Long) {
        while (spinCount < count) {
            repeat(Paylines.REELS) { rng.next() }
            spinCount++
        }
    }

    fun spin(betPerLine: Int): SpinResult {
        val stops = IntArray(Paylines.REELS) { rng.next(strips[it].size) }
        spinCount++

        val honest = evaluate(stops, betPerLine)

        // Presentation stream, not the game stream.
        if (!nearMiss.enabled) return honest
        if (presentationRng.next(10_000) / 10_000.0 >= nearMiss.rate) return honest
        return findTease(stops, betPerLine, honest) ?: honest
    }

    /** Pure evaluation, split out so tests can feed in fixed stop positions. */
    fun evaluate(stops: IntArray, betPerLine: Int): SpinResult {
        val grid = buildGrid(stops)
        val totalBet = betPerLine * Paylines.count

        val lineWins = ArrayList<LineWin>()
        var lineTotal = 0
        for ((lineIndex, line) in Paylines.all.withIndex()) {
            val win = evaluateLine(grid, line, lineIndex, betPerLine) ?: continue
            lineWins.add(win)
            lineTotal += win.credits
        }

        var scatterCount = 0
        for (reel in 0 until Paylines.REELS)
            for (row in 0 until Paylines.ROWS)
                if (grid[reel][row].isScatter) scatterCount++

        val scatterCredits = Paytable.scatterPay(scatterCount, volatility) * totalBet

        return SpinResult(
            grid = grid,
            stops = stops,
            lineWins = lineWins.sortedByDescending { it.credits },
            scatterCount = scatterCount,
            scatterCredits = scatterCredits,
            freeSpinsAwarded = Paytable.freeSpins(scatterCount),
            totalBet = totalBet,
            totalWin = lineTotal + scatterCredits,
            nearMiss = null,
            anticipation = anticipationFlags(grid),
        )
    }

    /** Reads three consecutive strip positions per reel, wrapping at the end. */
    fun buildGrid(stops: IntArray): List<List<Symbol>> =
        (0 until Paylines.REELS).map { reel ->
            val strip = strips[reel]
            (0 until Paylines.ROWS).map { row -> strip[(stops[reel] + row) % strip.size] }
        }

    /**
     * Left-to-right matching with wild substitution.
     *
     * The subtlety: the Crown is both the wild *and* the top line symbol, so a line
     * starting with crowns has two readings — pay it as crowns, or let the crowns
     * stand in for what follows. Both are evaluated and the better one wins, which is
     * how real machines resolve it.
     */
    private fun evaluateLine(
        grid: List<List<Symbol>>, line: IntArray, lineIndex: Int, betPerLine: Int,
    ): LineWin? {

        fun run(target: Symbol): Int {
            var length = 0
            for (reel in 0 until Paylines.REELS) {
                val s = grid[reel][line[reel]]
                if (s == target || (s.isWild && !target.isWild)) length++ else break
            }
            return length
        }

        fun makeWin(symbol: Symbol, count: Int): LineWin? {
            val pay = Paytable.linePay(symbol, count, volatility) * betPerLine
            if (pay <= 0) return null
            return LineWin(lineIndex, symbol, count, pay,
                (0 until count).map { it to line[it] })
        }

        val first = grid[0][line[0]]
        // A scatter on reel 1 can't start a line win, and nothing substitutes for it.
        if (first.isScatter) return null

        var best: LineWin? = null
        if (first.isWild) {
            // Reading A: pure crowns.
            makeWin(Symbol.CROWN, run(Symbol.CROWN))?.let { best = it }
            // Reading B: leading crowns substitute for the next real symbol.
            for (reel in 1 until Paylines.REELS) {
                val s = grid[reel][line[reel]]
                if (s.isWild) continue
                if (s.isScatter) break
                val w = makeWin(s, run(s))
                if (w != null && w.credits > (best?.credits ?: 0)) best = w
                break
            }
        } else {
            best = makeWin(first, run(first))
        }
        return best
    }

    /**
     * Which reels the renderer should stall on: a reel earns anticipation when the
     * reels to its left have banked two scatters, or an unbroken run of 3+ on a
     * payline. Purely cosmetic — it reads a grid that is already final.
     */
    private fun anticipationFlags(grid: List<List<Symbol>>): BooleanArray {
        val flags = BooleanArray(Paylines.REELS)

        var seals = 0
        for (reel in 0 until Paylines.REELS) {
            if (seals >= 2) flags[reel] = true
            for (row in 0 until Paylines.ROWS) if (grid[reel][row].isScatter) seals++
        }

        for (line in Paylines.all) {
            val first = grid[0][line[0]]
            if (first.isScatter) continue
            var target = first
            if (first.isWild) {
                for (reel in 1 until Paylines.REELS) {
                    val s = grid[reel][line[reel]]
                    if (s.isWild) continue
                    if (s.isScatter) break
                    target = s; break
                }
            }
            if (target.isScatter || target.id < Symbol.KNIGHT.id) continue

            var run = 0
            for (reel in 0 until Paylines.REELS) {
                val s = grid[reel][line[reel]]
                if (s == target || (s.isWild && !target.isWild)) run++ else break
            }
            if (run in 3 until Paylines.REELS) flags[run] = true
        }
        return flags
    }

    /**
     * Searches for a single-reel nudge that dresses a result up as a visible near
     * miss without changing what it pays.
     *
     * The acceptance test is `totalWin` and `scatterCount` both unchanged — not
     * "still a loss". That distinction matters: requiring a loss makes the best tease
     * impossible, because four-of-a-kind always pays, so a four-match is never a
     * losing spin.
     */
    private fun findTease(stops: IntArray, betPerLine: Int, honest: SpinResult): SpinResult? {
        val grid = buildGrid(stops)

        data class Candidate(val line: Int, val breakReel: Int, val symbol: Symbol, val run: Int)
        val candidates = ArrayList<Candidate>()

        for ((lineIndex, line) in Paylines.all.withIndex()) {
            val first = grid[0][line[0]]
            if (first.isScatter) continue

            var target = first
            if (first.isWild) {
                for (reel in 1 until Paylines.REELS) {
                    val s = grid[reel][line[reel]]
                    if (s.isWild) continue
                    if (s.isScatter) break
                    target = s; break
                }
            }
            if (target.isScatter || target.id < nearMiss.minSymbolRank) continue

            var run = 0
            for (reel in 0 until Paylines.REELS) {
                val s = grid[reel][line[reel]]
                if (s == target || (s.isWild && !target.isWild)) run++ else break
            }
            if (run < 2 || run >= Paylines.REELS) continue
            candidates.add(Candidate(lineIndex, run, target, run))
        }
        if (candidates.isEmpty()) return null

        // Longest run first, then most valuable symbol.
        candidates.sortWith(compareByDescending<Candidate> { it.run }.thenByDescending { it.symbol.id })

        for (c in candidates.take(4)) {
            val line = Paylines.all[c.line]
            val lineRow = line[c.breakReel]
            val strip = strips[c.breakReel]
            val adjacentRows = listOf(lineRow - 1, lineRow + 1).filter { it in 0 until Paylines.ROWS }
            if (adjacentRows.isEmpty()) continue

            // Random start so the same tease doesn't recur identically.
            val offset = presentationRng.next(strip.size)
            for (i in strip.indices) {
                val candidateStop = (offset + i) % strip.size

                val landedRow = adjacentRows.firstOrNull {
                    strip[(candidateStop + it) % strip.size] == c.symbol
                } ?: continue
                // ...and NOT on the line itself, which would extend the run.
                if (strip[(candidateStop + lineRow) % strip.size] == c.symbol) continue

                val trial = stops.copyOf()
                trial[c.breakReel] = candidateStop
                val result = evaluate(trial, betPerLine)

                // The safety net that makes this RTP-neutral.
                if (result.totalWin != honest.totalWin) continue
                if (result.scatterCount != honest.scatterCount) continue

                return result.copy(
                    nearMiss = NearMiss(c.symbol, c.breakReel, landedRow, lineRow, c.run, c.line)
                )
            }
        }
        return null
    }
}
