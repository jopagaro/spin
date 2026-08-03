package com.royalspin.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.royalspin.R
import com.royalspin.core.Paylines
import com.royalspin.core.WinTier
import com.royalspin.game.GameViewModel
import java.text.NumberFormat

/**
 * MainActivity.kt — the Android screen.
 *
 * Layout is driven entirely by the cabinet artwork, exactly as on iOS: every
 * interactive element is positioned by normalised coordinates measured off
 * cabinet_frame.png. Change the artwork and you change [Cabinet]; nothing else moves.
 */

// ────────────────────────────────────────────────────────────────── Geometry ──

private object Cabinet {
    const val IMAGE_W = 1024.0
    const val IMAGE_H = 1536.0
    const val ASPECT = IMAGE_W / IMAGE_H

    /**
     * Draw the cabinet wider than the screen and clip the overhang.
     *
     * Symbol size is rigidly determined — the window is 68.55% of the cabinet width
     * and five symbols divide it — so the only way to enlarge symbols is to draw the
     * cabinet wider than the screen. Measured inward from the artwork's edge: the
     * base is clear to 14px, the columns to 34px, the lion heads begin at 45px (of
     * 1024). 1.18 trims the outer mane but leaves the lions plainly readable.
     */
    const val OVERSCALE = 1.18f

    /** Exact border colour of the artwork, so the cabinet has no seam on screen. */
    val BACKDROP = Color(0xFF00001D)

    /** Inside the machine, behind the reels. */
    val REEL_VOID = Color(0xFF150A2E)

    // The chroma-keyed reel window: x 159–860, y 465–1033.
    const val WIN_X0 = 159.0 / IMAGE_W
    const val WIN_X1 = 860.0 / IMAGE_W
    const val WIN_Y0 = 465.0 / IMAGE_H
    const val WIN_Y1 = 1033.0 / IMAGE_H
    val winMidX get() = (WIN_X0 + WIN_X1) / 2
    val winMidY get() = (WIN_Y0 + WIN_Y1) / 2
    val winW get() = WIN_X1 - WIN_X0
    val winH get() = WIN_Y1 - WIN_Y0

    /** Control slots: centre and interior size, normalised. */
    data class Slot(val cx: Double, val cy: Double, val w: Double, val h: Double)

    val BET_DOWN = Slot(189 / IMAGE_W, 1197 / IMAGE_H, 118 / IMAGE_W, 132 / IMAGE_H)
    val READOUT = Slot(379 / IMAGE_W, 1199 / IMAGE_H, 120 / IMAGE_W, 76 / IMAGE_H)
    val BET_UP = Slot(556 / IMAGE_W, 1197 / IMAGE_H, 118 / IMAGE_W, 132 / IMAGE_H)
    val SPIN = Slot(815 / IMAGE_W, 1200 / IMAGE_H, 152 / IMAGE_W, 152 / IMAGE_H)
}

private val GoldBrush = Brush.verticalGradient(
    listOf(Color(0xFFFFF0A8), Color(0xFFF2C247), Color(0xFFBD7A1A))
)
private val Gold = Color(0xFFF2C247)

private fun Int.grouped(): String = NumberFormat.getInstance().format(this)

// ────────────────────────────────────────────────────────────────── Activity ──

class MainActivity : ComponentActivity() {
    private val vm: GameViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { GameScreen(vm) }
    }
}

// ──────────────────────────────────────────────────────────────────── Screen ──

@Composable
fun GameScreen(vm: GameViewModel) {
    var spinTrigger by remember { mutableIntStateOf(0) }

    Box(
        Modifier
            .fillMaxSize()
            .background(Cabinet.BACKDROP)
    ) {
        Column(Modifier.fillMaxSize()) {
            TopBar(vm)
            CabinetView(vm, spinTrigger) { spinTrigger++ }
        }

        // Near-miss banner.
        vm.nearMissBanner?.let { nm ->
            Text(
                "SO CLOSE — ${nm.symbol.displayName.uppercase()} MISSED BY ONE",
                style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Black),
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 150.dp)
                    .clip(RoundedCornerShape(50))
                    .background(Color(0xD9C62828))
                    .padding(horizontal = 16.dp, vertical = 9.dp),
            )
        }

        // Big win callout.
        val r = vm.lastResult
        if (r != null && r.totalWin > 0 && !vm.isSpinning &&
            r.tier.ordinal >= WinTier.BIG.ordinal
        ) {
            Column(
                Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    when (r.tier) {
                        WinTier.JACKPOT -> "JACKPOT"
                        WinTier.MEGA -> "MEGA WIN"
                        else -> "BIG WIN"
                    },
                    style = TextStyle(
                        fontSize = 40.sp, fontWeight = FontWeight.Black,
                        fontFamily = FontFamily.Serif, brush = GoldBrush,
                    ),
                )
                Text(
                    "+${r.totalWin.grouped()}",
                    style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Black),
                    color = Color.White,
                )
            }
        }
    }
}

@Composable
private fun TopBar(vm: GameViewModel) {
    Row(
        Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 14.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column {
            Text(
                "CREDITS",
                style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Black, letterSpacing = 2.sp),
                color = Color.White.copy(alpha = 0.45f),
            )
            Text(
                vm.displayCredits.grouped(),
                style = TextStyle(
                    fontSize = 28.sp, fontWeight = FontWeight.Black,
                    fontFamily = FontFamily.Serif, brush = GoldBrush,
                ),
            )
        }

        Spacer(Modifier.weight(1f))

        if (vm.freeSpinsRemaining > 0) {
            Column(
                Modifier
                    .size(38.dp)
                    .clip(CircleShape)
                    .background(GoldBrush),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    "${vm.freeSpinsRemaining}",
                    style = TextStyle(fontSize = 17.sp, fontWeight = FontWeight.Black,
                                      fontFamily = FontFamily.Serif),
                    color = Color.Black,
                )
                Text("FREE", style = TextStyle(fontSize = 7.sp, fontWeight = FontWeight.Black),
                     color = Color.Black.copy(alpha = 0.7f))
            }
            Spacer(Modifier.width(8.dp))
        }

        ChromeButton("MAX", enabled = !vm.isSpinning) { vm.maxBet() }
    }
}

@Composable
private fun ChromeButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .height(36.dp)
            .widthIn(min = 52.dp)
            .clip(RoundedCornerShape(50))
            .background(Color.Black.copy(alpha = 0.45f))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            label,
            style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Black,
                              letterSpacing = 0.8.sp, brush = GoldBrush),
            modifier = Modifier.alpha(if (enabled) 1f else 0.35f),
        )
    }
}

// ─────────────────────────────────────────────────────────────────── Cabinet ──

@Composable
private fun ColumnScope.CabinetView(vm: GameViewModel, spinTrigger: Int, onSpin: () -> Unit) {
    BoxWithConstraints(
        Modifier
            .fillMaxWidth()
            .weight(1f)
            .clipToBounds(),
    ) {
        // Wants OVERSCALE × the container width, but never taller than the container
        // so the crown and base never clip. On a short device the height cap wins and
        // this degrades gracefully to a plain fit.
        val cw: Dp = minOf(maxWidth * Cabinet.OVERSCALE, maxHeight * Cabinet.ASPECT.toFloat())
        val ch: Dp = cw / Cabinet.ASPECT.toFloat()
        val ox = (maxWidth - cw) / 2
        val oy = (maxHeight - ch) / 2

        /** Place content of normalised size at a normalised centre of the artwork. */
        @Composable
        fun slot(s: Cabinet.Slot, content: @Composable BoxScope.() -> Unit) {
            val w = cw * s.w.toFloat()
            val h = ch * s.h.toFloat()
            Box(
                Modifier
                    .offset(x = ox + cw * s.cx.toFloat() - w / 2,
                            y = oy + ch * s.cy.toFloat() - h / 2)
                    .size(w, h),
                contentAlignment = Alignment.Center,
                content = content,
            )
        }

        // Dark interior, filling the whole window.
        Box(
            Modifier
                .offset(x = ox + cw * Cabinet.WIN_X0.toFloat(),
                        y = oy + ch * Cabinet.WIN_Y0.toFloat())
                .size(cw * Cabinet.winW.toFloat(), ch * Cabinet.winH.toFloat())
                .background(Cabinet.REEL_VOID)
        )

        // Reels. The viewport is deliberately shorter than the window: three full
        // rows plus a sliver above and below, with the leftover band showing
        // REEL_VOID. See the iOS Cabinet.Window doc comment for the derivation.
        val cellSize = cw * (Cabinet.winW / Paylines.REELS).toFloat()
        Box(
            Modifier
                .offset(x = ox + cw * Cabinet.WIN_X0.toFloat(),
                        y = oy + ch * Cabinet.winMidY.toFloat() - cellSize * 1.625f)
                .size(cw * Cabinet.winW.toFloat(), cellSize * 3.25f)
                .clipToBounds(),
            contentAlignment = Alignment.Center,
        ) {
            ReelBank(
                result = vm.lastResult,
                spinTrigger = spinTrigger,
                onReelStopped = vm::reelDidStop,
                onSpinComplete = vm::spinDidFinish,
                cellSize = cellSize,
            )
        }

        // Cabinet artwork on top, framed to exactly the same rect the slots use.
        Image(
            painter = painterResource(R.drawable.cabinet_frame),
            contentDescription = null,
            contentScale = ContentScale.FillBounds,
            modifier = Modifier.offset(x = ox, y = oy).size(cw, ch),
        )

        // ── Controls, seated in the cabinet's own frames ──

        slot(Cabinet.BET_DOWN) {
            BetGlyph(minus = true, enabled = !vm.isSpinning && vm.canAdjustBet(up = false)) {
                vm.adjustBet(-1)
            }
        }

        slot(Cabinet.READOUT) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("BET", style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Black,
                                              letterSpacing = 1.5.sp),
                     color = Color.White.copy(alpha = 0.6f))
                Text(
                    vm.totalBet.grouped(),
                    style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Black,
                                      fontFamily = FontFamily.Serif, brush = GoldBrush),
                    textAlign = TextAlign.Center,
                )
            }
        }

        slot(Cabinet.BET_UP) {
            BetGlyph(minus = false, enabled = !vm.isSpinning && vm.canAdjustBet(up = true)) {
                vm.adjustBet(1)
            }
        }

        slot(Cabinet.SPIN) {
            SpinButton(enabled = vm.canSpin, free = vm.isFreeSpin) {
                if (vm.beginSpin() != null) onSpin()
            }
        }
    }
}

/**
 * Bet +/− drawn as solid gold bars rather than a system icon, which would read as
 * platform UI pasted onto a hand-painted cabinet.
 */
@Composable
private fun BoxScope.BetGlyph(minus: Boolean, enabled: Boolean, onClick: () -> Unit) {
    BoxWithConstraints(
        Modifier
            .matchParentSize()
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        val s = minOf(maxWidth, maxHeight)
        // Still clearly visible when disabled: too faint reads as a missing button
        // rather than a bet already at its limit.
        val a = if (enabled) 1f else 0.45f
        Box(
            Modifier
                .size(s * 0.46f, s * 0.115f)
                .clip(RoundedCornerShape(50))
                .background(GoldBrush)
                .alpha(a)
        )
        if (!minus) {
            Box(
                Modifier
                    .size(s * 0.115f, s * 0.46f)
                    .clip(RoundedCornerShape(50))
                    .background(GoldBrush)
                    .alpha(a)
            )
        }
    }
}

@Composable
private fun BoxScope.SpinButton(enabled: Boolean, free: Boolean, onClick: () -> Unit) {
    Box(
        Modifier
            .matchParentSize()
            .clip(CircleShape)
            .background(
                if (enabled) Brush.radialGradient(
                    listOf(Color(0xFFFFE07A), Color(0xFFE68F1A), Color(0xFF7A3005))
                ) else Brush.radialGradient(listOf(Color(0xFF575757), Color(0xFF292929)))
            )
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            if (free) "FREE" else "SPIN",
            style = TextStyle(fontSize = 21.sp, fontWeight = FontWeight.Black,
                              fontFamily = FontFamily.Serif),
            color = if (enabled) Color(0xFF421A00) else Color.White.copy(alpha = 0.35f),
        )
    }
}
