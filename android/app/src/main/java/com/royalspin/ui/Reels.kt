package com.royalspin.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.royalspin.core.Paylines
import com.royalspin.core.ReelStrips
import com.royalspin.core.SpinResult
import com.royalspin.core.Symbol
import kotlinx.coroutines.android.awaitFrame
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin

/**
 * Reels.kt — the 3D reels.
 *
 * Same construction as the iOS SceneKit version, expressed in Compose: each reel is
 * a ring of reusable symbol tiles, and the ring rotates. There are no per-frame
 * texture sequences anywhere — one static drawable per symbol, recycled as tiles come
 * around, exactly as assets/symbols/README.md specifies.
 *
 * The 3D is real perspective, not a fake gradient. Each tile is placed on a cylinder
 * of radius R at angle aₖ = −k·Δ − ψ:
 *
 *   · vertical offset  = −R·sin(aₖ) · cell        (screen Y grows downward)
 *   · rotationX        = aₖ in degrees            (tile lies tangent to the cylinder)
 *   · cameraDistance   gives the foreshortening    (see [CAMERA_DISTANCE])
 *
 * Increasing ψ therefore scrolls symbols downward, the direction a real reel spins,
 * and landing on ψ ≡ 0 (mod 2π) always puts tile 0 back at centre — which is why the
 * textures can be assigned once before the spin and never touched mid-flight.
 */

object ReelTuning {
    /** Tiles per ring. Enough that you never see through the gap between them. */
    const val PANEL_COUNT = 14

    /**
     * Cylinder radius in cell units. Vertical spacing between neighbouring tiles at
     * the front is R·sin(Δ), which must be at least 1 cell for rows not to overlap:
     * R ≥ 1 / sin(2π/14) = 2.304.
     */
    const val RADIUS = 2.35

    /**
     * Compose's perspective strength, in units of density. 8–16 is the usual range;
     * lower is a wider-angle, more dramatic curve. This is tuned to roughly match the
     * iOS camera's 42° horizontal field of view.
     */
    const val CAMERA_DISTANCE = 11f

    val cellAngle: Double get() = 2 * PI / PANEL_COUNT

    // Timing. Same phase structure as the spec in assets/symbols/README.md, with
    // durations stretched past its minimums — at the spec timings the whole spin was
    // over in under a second, which reads as a glitch rather than a machine.
    const val MAX_SPEED = 14.0          // rad/s ≈ 31 symbols/sec
    const val SPIN_UP = 0.34
    const val BASE_CRUISE = 0.90
    const val STAGGER = 0.30            // each reel keeps going this much longer
    const val ANTICIPATION_HOLD = 1.30  // extra cruise when a bonus is still live
    const val DECEL = 0.62
    const val BOUNCE_TIME = 0.16
    val bounceAngle: Double get() = cellAngle * 0.07
}

private enum class Phase { IDLE, SPIN_UP, CRUISE, DECEL, BOUNCE }

/** Mutable per-reel animation state. Deliberately plain — it's written every frame. */
private class ReelState(val index: Int) {
    var phase = Phase.IDLE
    var angle = 0.0
    var speed = 0.0
    var phaseStart = 0.0
    var cruiseUntil = 0.0
    var from = 0.0
    var to = 0.0
    /** Strip position this reel will land on. */
    var stop = 0
}

/**
 * The reel bank.
 *
 * @param spinTrigger increment to start a spin toward [result].
 * @param onReelStopped fired as each reel lands, for the per-reel knock.
 * @param onSpinComplete fired once every reel has settled.
 */
@Composable
fun ReelBank(
    result: SpinResult?,
    spinTrigger: Int,
    onReelStopped: (Int) -> Unit,
    onSpinComplete: () -> Unit,
    modifier: Modifier = Modifier,
    cellSize: Dp,
) {
    val context = LocalContext.current
    val density = LocalDensity.current

    // Resolve drawable ids once. A missing drawable resolves to 0 and is skipped
    // rather than crashing, so art can be dropped in one symbol at a time.
    val drawables = remember {
        Symbol.all.associateWith { s ->
            context.resources.getIdentifier(s.drawableName, "drawable", context.packageName)
        }
    }

    val reels = remember { List(Paylines.REELS) { ReelState(it) } }

    // Which symbol each tile shows, per reel. Assigned when a spin starts.
    val faces = remember {
        mutableStateListOf<SnapshotStateList<Symbol>>().apply {
            repeat(Paylines.REELS) { reel ->
                val strip = ReelStrips.strips[reel]
                add(mutableStateListOf<Symbol>().apply {
                    repeat(ReelTuning.PANEL_COUNT) { k -> add(strip[k % strip.size]) }
                })
            }
        }
    }

    // Recomposition ticker: bumped every frame while spinning.
    var frame by remember { mutableIntStateOf(0) }
    var running by remember { mutableStateOf(false) }

    fun applyFaces(reel: Int, stop: Int) {
        val strip = ReelStrips.strips[reel]
        // Tile 0 is centre-front, which is grid row 1, and the grid reads
        // strip[stop], strip[stop+1], strip[stop+2] top to bottom — hence the +1.
        for (k in 0 until ReelTuning.PANEL_COUNT) {
            faces[reel][k] = strip[(stop + 1 + k) % strip.size]
        }
    }

    // Start a spin whenever the trigger changes.
    LaunchedEffect(spinTrigger) {
        val r = result ?: return@LaunchedEffect
        if (spinTrigger == 0) return@LaunchedEffect
        for ((i, reel) in reels.withIndex()) {
            reel.stop = r.stops[i]
            // Textures are set now, at the start. By the time the reel decelerates
            // it already shows the right symbols — invisible during the blur, and it
            // avoids a visible pop from a late swap.
            applyFaces(i, reel.stop)
            reel.angle = 0.0
            reel.speed = 0.0
            reel.phase = Phase.SPIN_UP
            reel.phaseStart = 0.0
        }
        running = true
    }

    // The animation loop. `awaitFrame` ties updates to the display refresh.
    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        var last = withFrameSecondsCompat()
        val startedAt = last
        for (reel in reels) reel.phaseStart = startedAt

        while (running) {
            val now = withFrameSecondsCompat()
            val dt = (now - last).coerceAtMost(1.0 / 20.0)   // clamp so a hitch can't fling a reel
            last = now
            if (dt <= 0) continue

            var allIdle = true
            for (reel in reels) {
                when (reel.phase) {
                    Phase.IDLE -> {}

                    Phase.SPIN_UP -> {
                        allIdle = false
                        val t = ((now - reel.phaseStart) / ReelTuning.SPIN_UP).coerceAtMost(1.0)
                        reel.speed = ReelTuning.MAX_SPEED * t * t     // ease in: it has mass
                        reel.angle += reel.speed * dt
                        if (t >= 1.0) {
                            var cruise = ReelTuning.BASE_CRUISE + reel.index * ReelTuning.STAGGER
                            if (result?.anticipation?.getOrNull(reel.index) == true) {
                                cruise += ReelTuning.ANTICIPATION_HOLD
                            }
                            reel.cruiseUntil = now + cruise
                            reel.phase = Phase.CRUISE
                        }
                    }

                    Phase.CRUISE -> {
                        allIdle = false
                        reel.speed = ReelTuning.MAX_SPEED
                        reel.angle += reel.speed * dt
                        if (now >= reel.cruiseUntil) {
                            // Land on the next whole turn that leaves enough runway to
                            // decelerate smoothly; otherwise a reel just past 2π slams
                            // to a halt.
                            val minTravel = reel.speed * ReelTuning.DECEL * 0.5
                            val twoPi = 2 * PI
                            reel.from = reel.angle
                            reel.to = kotlin.math.ceil((reel.angle + minTravel) / twoPi) * twoPi
                            reel.phaseStart = now
                            reel.phase = Phase.DECEL
                        }
                    }

                    Phase.DECEL -> {
                        allIdle = false
                        val t = ((now - reel.phaseStart) / ReelTuning.DECEL).coerceAtMost(1.0)
                        val eased = 1 - (1 - t).pow(3)          // fast arrival, soft landing
                        reel.angle = reel.from + (reel.to - reel.from) * eased
                        if (t >= 1.0) {
                            reel.angle = reel.to
                            reel.from = reel.to
                            reel.to = reel.to + ReelTuning.bounceAngle
                            reel.phaseStart = now
                            reel.phase = Phase.BOUNCE
                        }
                    }

                    Phase.BOUNCE -> {
                        allIdle = false
                        val t = ((now - reel.phaseStart) / ReelTuning.BOUNCE_TIME).coerceAtMost(1.0)
                        // Out and back — the recoil of a reel hitting its detent.
                        reel.angle = reel.from + (reel.to - reel.from) * sin(t * PI)
                        if (t >= 1.0) {
                            reel.angle = reel.from
                            reel.speed = 0.0
                            reel.phase = Phase.IDLE
                            onReelStopped(reel.index)
                        }
                    }
                }
            }

            frame++      // drive recomposition
            if (allIdle) {
                running = false
                onSpinComplete()
            }
        }
    }

    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        for (reel in reels) {
            key(reel.index) {
                Box(
                    modifier = Modifier.size(cellSize, cellSize * 4),
                    contentAlignment = Alignment.Center,
                ) {
                    // `frame` is read here so this Box recomposes each tick.
                    @Suppress("UNUSED_EXPRESSION") frame

                    val cellPx = with(density) { cellSize.toPx() }
                    val delta = ReelTuning.cellAngle

                    for (k in 0 until ReelTuning.PANEL_COUNT) {
                        val a = -k * delta - reel.angle
                        val cosA = cos(a)
                        // Skip the back half of the ring entirely — roughly half the
                        // draw calls for something the player can never see.
                        if (cosA <= 0.05) continue

                        val symbol = faces[reel.index][k]
                        val resId = drawables[symbol] ?: 0
                        if (resId == 0) continue

                        Image(
                            painter = painterResource(resId),
                            contentDescription = symbol.displayName,
                            contentScale = ContentScale.Fit,
                            modifier = Modifier
                                .size(cellSize)
                                .graphicsLayer {
                                    // Screen Y grows downward, world Y grows up.
                                    translationY = (-ReelTuning.RADIUS * sin(a) * cellPx).toFloat()
                                    rotationX = Math.toDegrees(a).toFloat()
                                    cameraDistance = ReelTuning.CAMERA_DISTANCE * this.density
                                    // Fade toward the cabinet interior at the edges,
                                    // so symbols sink into the machine instead of
                                    // reading as a flat collage.
                                    alpha = (0.12 + 0.88 * cosA.pow(1.7)).toFloat()
                                },
                        )
                    }
                }
            }
        }
    }
}

/** Frame timestamp in seconds. */
private suspend fun withFrameSecondsCompat(): Double = awaitFrame() / 1_000_000_000.0
