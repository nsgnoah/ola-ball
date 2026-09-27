package co.nsgsolutions.spinola.ui.hud

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.dp
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

// Ported from Views/Icons.swift. Every path keeps the Swift coordinates in a 100x100 space.
// Two argument-order traps when reading the two side by side: SwiftUI's addQuadCurve(to:control:)
// names the END point first, Compose's quadraticTo(cx, cy, x, y) takes the CONTROL point first;
// likewise addCurve(to:control1:control2:) becomes cubicTo(c1, c2, end). Arcs: SwiftUI's
// addArc(clockwise: false) in a y-down space walks increasing angles, which is exactly Android's
// arcTo with a positive sweep, so sweep = (end - start) mod 360 and the start angle is unchanged.
// Rotation is positive-clockwise on screen in both, so degrees pass straight through.

/**
 * Every icon in the game is drawn here from primitives, in one sticker style:
 * a light fill with a rounded ink outline and a few ink details. Nothing from Material icons.
 *
 * Like a SwiftUI `Canvas`, the art fills whatever bounds the modifier gives it, with the 100x100
 * design space fitted to the shorter side and centred.
 */
@Composable
fun DeckIcon(deckID: String, fill: Color = Color.White, ink: Color = Theme.ink, modifier: Modifier = Modifier) {
    Canvas(modifier.fillMaxSize()) {
        inIconSpace { with(IconArt) { drawDeck(deckID, fill, ink) } }
    }
}

/** Maps the canvas onto the 100x100 design space: scaled to the shorter side and centred. */
private fun DrawScope.inIconSpace(block: DrawScope.() -> Unit) {
    val s = min(size.width, size.height) / 100f
    withTransform({
        translate((size.width - 100f * s) / 2f, (size.height - 100f * s) / 2f)
        scale(s, s, Offset.Zero)
    }) { block() }
}

private inline fun path(build: Path.() -> Unit): Path = Path().apply(build)

object IconArt {
    const val line = 5.5f

    fun DrawScope.stroke(p: Path, ink: Color, width: Float = line) {
        drawPath(p, ink, style = Stroke(width = width, cap = StrokeCap.Round, join = StrokeJoin.Round))
    }

    fun DrawScope.shape(p: Path, fill: Color, ink: Color) {
        drawPath(p, fill)
        stroke(p, ink)
    }

    fun rr(x: Float, y: Float, w: Float, h: Float, r: Float): Path =
        path { addRoundRect(RoundRect(Rect(x, y, x + w, y + h), CornerRadius(r))) }

    fun rect(x: Float, y: Float, w: Float, h: Float): Path = path { addRect(Rect(x, y, x + w, y + h)) }

    /** `Path(ellipseIn:)`: the ellipse inscribed in the rectangle. */
    fun oval(x: Float, y: Float, w: Float, h: Float): Path = path { addOval(Rect(x, y, x + w, y + h)) }

    fun circle(cx: Float, cy: Float, r: Float): Path = path { addOval(Rect(cx - r, cy - r, cx + r, cy + r)) }

    fun lineTo(x1: Float, y1: Float, x2: Float, y2: Float): Path = path { moveTo(x1, y1); lineTo(x2, y2) }

    fun poly(vararg pts: Pair<Float, Float>): Path = path {
        val first = pts.firstOrNull() ?: return@path
        moveTo(first.first, first.second)
        for (i in 1 until pts.size) lineTo(pts[i].first, pts[i].second)
        close()
    }

    /** Run [body] with the canvas rotated around a pivot. */
    fun DrawScope.rotated(degrees: Float, pivotX: Float, pivotY: Float, body: DrawScope.() -> Unit) {
        withTransform({ rotate(degrees, Offset(pivotX, pivotY)) }) { body() }
    }

    /** Run [body] clipped to [p]: the Swift `clip(to:)` on a copied context. */
    fun DrawScope.clipped(p: Path, body: DrawScope.() -> Unit) {
        clipPath(p) { body() }
    }

    fun DrawScope.drawDeck(id: String, fill: Color, ink: Color) {
        when (id) {
            "skincare" -> skincare(fill, ink)
            "fashion" -> fashion(fill, ink)
            "romcoms" -> romcoms(fill, ink)
            "reality" -> reality(fill, ink)
            "divas" -> divas(fill, ink)
            "weddings" -> weddings(fill, ink)
            "bookclub" -> bookclub(fill, ink)
            "wellness" -> wellness(fill, ink)
            "gossip" -> gossip(fill, ink)
            "football" -> football(fill, ink)
            "ballsports" -> ballsports(fill, ink)
            "cars" -> cars(fill, ink)
            "grill" -> grill(fill, ink)
            "nerd" -> nerd(fill, ink)
            "gear" -> gear(fill, ink)
            "actionmovies" -> actionmovies(fill, ink)
            "tech" -> tech(fill, ink)
            "fightnight" -> fightnight(fill, ink)
            else -> shape(circle(50f, 50f, 30f), fill, ink)
        }
    }

    // MARK: Her World

    /** Serum dropper with a drop beside it. */
    private fun DrawScope.skincare(fill: Color, ink: Color) {
        shape(rr(30f, 38f, 40f, 54f, 10f), fill, ink)
        shape(rr(43f, 26f, 14f, 14f, 3f), fill, ink)
        shape(oval(36f, 6f, 28f, 24f), fill, ink)
        drawPath(rr(40f, 58f, 20f, 14f, 3f), ink)
        val d = path {
            moveTo(82f, 50f)
            quadraticTo(88f, 56f, 90f, 66f)
            arcTo(Rect(74f, 58f, 90f, 74f), 0f, 180f, false)
            quadraticTo(76f, 56f, 82f, 50f)
            close()
        }
        shape(d, fill, ink)
    }

    /** Handbag with a clasp. */
    private fun DrawScope.fashion(fill: Color, ink: Color) {
        val handle = path {
            moveTo(34f, 44f)
            quadraticTo(50f, 4f, 66f, 44f)
        }
        stroke(handle, ink, 6f)
        val b = path {
            moveTo(20f, 44f)
            lineTo(80f, 44f)
            quadraticTo(86f, 66f, 86f, 90f)
            quadraticTo(50f, 96f, 14f, 90f)
            quadraticTo(14f, 66f, 20f, 44f)
            close()
        }
        shape(b, fill, ink)
        drawPath(oval(43f, 48f, 14f, 9f), ink)
        stroke(lineTo(20f, 60f, 80f, 60f), ink, 3f)
    }

    /** Heart with an arrow through it. */
    private fun DrawScope.romcoms(fill: Color, ink: Color) {
        val h = path {
            moveTo(50f, 90f)
            cubicTo(25f, 78f, 5f, 60f, 10f, 40f)
            cubicTo(14f, 16f, 44f, 14f, 50f, 30f)
            cubicTo(56f, 14f, 86f, 16f, 90f, 40f)
            cubicTo(95f, 60f, 75f, 78f, 50f, 90f)
            close()
        }
        shape(h, fill, ink)
        stroke(lineTo(16f, 86f, 84f, 16f), ink, 5f)
        drawPath(poly(86f to 14f, 70f to 18f, 82f to 30f), ink)
        stroke(lineTo(16f, 86f, 22f, 72f), ink, 4f)
        stroke(lineTo(16f, 86f, 30f, 80f), ink, 4f)
    }

    /** A rose on a stem. */
    private fun DrawScope.reality(fill: Color, ink: Color) {
        val stem = path {
            moveTo(50f, 94f)
            quadraticTo(57f, 76f, 50f, 56f)
        }
        stroke(stem, ink, 5f)
        rotated(35f, 66f, 74f) {
            shape(oval(54f, 68f, 24f, 12f), fill, ink)
        }
        shape(circle(50f, 36f, 22f), fill, ink)
        // 20° to 240° and 200° to 60°, both walking increasing angles.
        val petal = path { arcTo(Rect(38f, 24f, 62f, 48f), 20f, 220f, true) }
        stroke(petal, ink, 4f)
        val inner = path { arcTo(Rect(46f, 30f, 56f, 40f), 200f, 220f, true) }
        stroke(inner, ink, 4f)
    }

    /** Stage microphone. */
    private fun DrawScope.divas(fill: Color, ink: Color) {
        shape(rr(42f, 56f, 16f, 36f, 8f), fill, ink)
        drawPath(rr(46f, 66f, 8f, 5f, 2f), ink)
        shape(rr(36f, 50f, 28f, 9f, 4f), fill, ink)
        val head = circle(50f, 32f, 23f)
        shape(head, fill, ink)
        clipped(head) {
            for (y in floatArrayOf(24f, 32f, 40f)) stroke(lineTo(22f, y, 78f, y), ink, 3.5f)
            for (x in floatArrayOf(40f, 50f, 60f)) stroke(lineTo(x, 8f, x, 56f), ink, 3.5f)
        }
    }

    /** Diamond ring. */
    private fun DrawScope.weddings(fill: Color, ink: Color) {
        val band = circle(50f, 62f, 26f).apply {
            addPath(circle(50f, 62f, 16f))
            fillType = PathFillType.EvenOdd
        }
        drawPath(band, fill)
        stroke(circle(50f, 62f, 26f), ink)
        stroke(circle(50f, 62f, 16f), ink)
        val gem = poly(50f to 6f, 68f to 24f, 50f to 44f, 32f to 24f)
        shape(gem, fill, ink)
        stroke(lineTo(34f, 24f, 66f, 24f), ink, 3.5f)
        stroke(lineTo(42f, 24f, 50f, 42f), ink, 3f)
        stroke(lineTo(58f, 24f, 50f, 42f), ink, 3f)
    }

    /** Open book. */
    private fun DrawScope.bookclub(fill: Color, ink: Color) {
        val l = path {
            moveTo(12f, 26f)
            quadraticTo(31f, 22f, 50f, 34f)
            lineTo(50f, 88f)
            quadraticTo(31f, 76f, 12f, 80f)
            close()
        }
        val r = path {
            moveTo(88f, 26f)
            quadraticTo(69f, 22f, 50f, 34f)
            lineTo(50f, 88f)
            quadraticTo(69f, 76f, 88f, 80f)
            close()
        }
        shape(l, fill, ink)
        shape(r, fill, ink)
        floatArrayOf(42f, 53f, 64f).forEachIndexed { i, y ->
            val w = if (i == 2) 14f else 20f
            stroke(lineTo(20f, y, 20f + w, y + 3f), ink, 3f)
            stroke(lineTo(80f, y, 80f - w, y + 3f), ink, 3f)
        }
    }

    /** Lotus over water. */
    private fun DrawScope.wellness(fill: Color, ink: Color) {
        val petal = oval(39f, 18f, 22f, 58f)
        for (deg in floatArrayOf(-38f, 38f)) {
            rotated(deg, 50f, 76f) { shape(petal, fill, ink) }
        }
        shape(petal, fill, ink)
        val water = path {
            moveTo(14f, 86f)
            quadraticTo(50f, 100f, 86f, 86f)
        }
        stroke(water, ink, 5f)
    }

    /** Sunglasses. */
    private fun DrawScope.gossip(fill: Color, ink: Color) {
        stroke(lineTo(10f, 46f, 2f, 36f), ink, 5f)
        stroke(lineTo(90f, 46f, 98f, 36f), ink, 5f)
        stroke(lineTo(45f, 46f, 55f, 46f), ink, 5f)
        for (x in floatArrayOf(8f, 54f)) {
            val lens = rr(x, 36f, 38f, 30f, 13f)
            shape(lens, fill, ink)
            clipped(lens) {
                drawPath(rect(x, 50f, 38f, 16f), ink)
                stroke(lineTo(x + 8f, 60f, x + 14f, 54f), fill, 3f)
            }
        }
    }

    // MARK: His World

    /** Football with laces. */
    private fun DrawScope.football(fill: Color, ink: Color) {
        rotated(-25f, 50f, 50f) {
            // Cubic curves on purpose: a closed pair of quad curves doesn't fill in Canvas.
            val b = path {
                moveTo(8f, 50f)
                cubicTo(28f, 12f, 72f, 12f, 92f, 50f)
                cubicTo(72f, 88f, 28f, 88f, 8f, 50f)
                close()
            }
            shape(b, fill, ink)
            stroke(lineTo(34f, 50f, 66f, 50f), ink, 4f)
            for (x in floatArrayOf(40f, 48f, 56f, 62f)) stroke(lineTo(x, 44f, x, 56f), ink, 4f)
            stroke(lineTo(20f, 36f, 24f, 64f), ink, 4f)
            stroke(lineTo(80f, 36f, 76f, 64f), ink, 4f)
        }
    }

    /** Basketball. */
    private fun DrawScope.ballsports(fill: Color, ink: Color) {
        val ball = circle(50f, 50f, 40f)
        shape(ball, fill, ink)
        clipped(ball) {
            stroke(lineTo(50f, 8f, 50f, 92f), ink, 4f)
            stroke(lineTo(8f, 50f, 92f, 50f), ink, 4f)
            stroke(circle(-4f, 50f, 46f), ink, 4f)
            stroke(circle(104f, 50f, 46f), ink, 4f)
        }
    }

    /** Car, side view. */
    private fun DrawScope.cars(fill: Color, ink: Color) {
        val b = path {
            moveTo(8f, 70f)
            lineTo(8f, 56f)
            quadraticTo(10f, 50f, 22f, 50f)
            lineTo(34f, 34f)
            quadraticTo(36f, 30f, 42f, 30f)
            lineTo(60f, 30f)
            quadraticTo(66f, 30f, 70f, 34f)
            lineTo(82f, 50f)
            quadraticTo(90f, 50f, 92f, 56f)
            lineTo(92f, 70f)
            quadraticTo(92f, 74f, 86f, 74f)
            lineTo(14f, 74f)
            quadraticTo(8f, 74f, 8f, 70f)
            close()
        }
        shape(b, fill, ink)
        drawPath(poly(32f to 50f, 41f to 37f, 61f to 37f, 69f to 50f), ink)
        drawPath(rect(48f, 37f, 4f, 13f), fill)
        for (x in floatArrayOf(28f, 72f)) {
            drawPath(circle(x, 72f, 10f), ink)
            drawPath(circle(x, 72f, 4f), fill)
        }
    }

    /** Kettle grill. */
    private fun DrawScope.grill(fill: Color, ink: Color) {
        stroke(lineTo(36f, 72f, 30f, 94f), ink, 5f)
        stroke(lineTo(64f, 72f, 70f, 94f), ink, 5f)
        shape(circle(50f, 44f, 32f), fill, ink)
        stroke(lineTo(18f, 44f, 82f, 44f), ink, 5f)
        drawPath(rr(41f, 4f, 18f, 9f, 4f), ink)
        val flame = path {
            moveTo(50f, 52f)
            quadraticTo(60f, 54f, 58f, 64f)
            quadraticTo(50f, 74f, 42f, 64f)
            quadraticTo(40f, 54f, 50f, 52f)
            close()
        }
        drawPath(flame, ink)
    }

    /** Game controller. */
    private fun DrawScope.nerd(fill: Color, ink: Color) {
        shape(circle(26f, 62f, 16f), fill, ink)
        shape(circle(74f, 62f, 16f), fill, ink)
        val body = rr(8f, 30f, 84f, 40f, 20f)
        drawPath(body, fill)
        stroke(body, ink)
        drawPath(rr(24f, 42f, 8f, 22f, 2.5f), ink)
        drawPath(rr(17f, 49f, 22f, 8f, 2.5f), ink)
        for ((x, y) in listOf(68f to 42f, 77f to 51f, 59f to 51f, 68f to 60f)) drawPath(circle(x, y, 4.5f), ink)
    }

    /** Hammer, tilted. */
    private fun DrawScope.gear(fill: Color, ink: Color) {
        rotated(-35f, 50f, 50f) {
            shape(rr(45f, 30f, 10f, 62f, 5f), fill, ink)
            shape(rr(28f, 10f, 44f, 22f, 6f), fill, ink)
            drawPath(rr(28f, 10f, 12f, 22f, 4f), ink)
        }
    }

    /** Clapperboard. */
    private fun DrawScope.actionmovies(fill: Color, ink: Color) {
        shape(rr(12f, 44f, 76f, 44f, 6f), fill, ink)
        stroke(lineTo(22f, 60f, 78f, 60f), ink, 3f)
        stroke(lineTo(22f, 72f, 60f, 72f), ink, 3f)
        rotated(-14f, 14f, 44f) {
            val bar = rr(12f, 26f, 76f, 18f, 4f)
            shape(bar, fill, ink)
            clipped(bar) {
                for (x in floatArrayOf(20f, 40f, 60f, 80f)) stroke(lineTo(x, 22f, x - 10f, 48f), ink, 7f)
            }
        }
        drawPath(circle(16f, 44f, 4.5f), ink)
    }

    /** Microchip. */
    private fun DrawScope.tech(fill: Color, ink: Color) {
        for (v in floatArrayOf(36f, 50f, 64f)) {
            stroke(lineTo(v, 26f, v, 14f), ink, 5f)
            stroke(lineTo(v, 74f, v, 86f), ink, 5f)
            stroke(lineTo(26f, v, 14f, v), ink, 5f)
            stroke(lineTo(74f, v, 86f, v), ink, 5f)
        }
        shape(rr(26f, 26f, 48f, 48f, 7f), fill, ink)
        drawPath(rr(40f, 40f, 20f, 20f, 4f), ink)
        drawPath(circle(50f, 50f, 3.5f), fill)
    }

    /** Boxing glove. */
    private fun DrawScope.fightnight(fill: Color, ink: Color) {
        shape(circle(27f, 58f, 13f), fill, ink)
        shape(rr(22f, 12f, 56f, 62f, 26f), fill, ink)
        shape(rr(34f, 70f, 44f, 20f, 6f), fill, ink)
        stroke(lineTo(40f, 80f, 72f, 80f), ink, 3f)
        stroke(lineTo(52f, 30f, 64f, 30f), ink, 4f)
        stroke(lineTo(52f, 40f, 64f, 40f), ink, 4f)
    }
}

// MARK: - Game glyphs (crown, trophy, phone, close)

/** A crown, gold when [filled], otherwise an outline in [empty]. [size] is in design points and scales with the window. */
@Composable
fun CrownIcon(filled: Boolean = true, size: Float = 18f, empty: Color = Theme.ink.copy(alpha = 0.18f), modifier: Modifier = Modifier) {
    val gold = Theme.gold
    val goldDeep = Theme.goldDeep
    Canvas(modifier.size(UI.s(size).dp)) {
        inIconSpace {
            with(IconArt) {
                val p = poly(12f to 82f, 12f to 34f, 32f to 52f, 50f to 18f, 68f to 52f, 88f to 34f, 88f to 82f)
                if (filled) {
                    drawPath(p, gold)
                    stroke(p, goldDeep, 7f)
                    for (x in floatArrayOf(30f, 50f, 70f)) drawPath(circle(x, 68f, 5f), goldDeep)
                } else {
                    stroke(p, empty, 7f)
                }
            }
        }
    }
}

@Composable
fun TrophyIcon(size: Float = 76f, modifier: Modifier = Modifier) {
    val gold = Theme.gold
    val goldDeep = Theme.goldDeep
    Canvas(modifier.size(UI.s(size).dp)) {
        inIconSpace {
            with(IconArt) {
                val l = path { moveTo(28f, 22f); quadraticTo(4f, 36f, 28f, 48f) }
                val r = path { moveTo(72f, 22f); quadraticTo(96f, 36f, 72f, 48f) }
                stroke(l, goldDeep, 7f)
                stroke(r, goldDeep, 7f)
                val cup = path {
                    moveTo(26f, 12f); lineTo(74f, 12f); lineTo(74f, 40f)
                    quadraticTo(74f, 62f, 50f, 64f)
                    quadraticTo(26f, 62f, 26f, 40f)
                    close()
                }
                shape(cup, gold, goldDeep)
                shape(rr(44f, 62f, 12f, 14f, 3f), gold, goldDeep)
                shape(rr(30f, 76f, 40f, 12f, 4f), gold, goldDeep)
                drawPath(poly(50f to 24f, 56f to 36f, 50f to 46f, 44f to 36f), goldDeep)
            }
        }
    }
}

/** Two phones passing: the hand-off glyph. */
@Composable
fun HandoffIcon(size: Float = 80f, modifier: Modifier = Modifier) {
    val ink = Theme.ink
    Canvas(modifier.size(UI.s(size).dp)) {
        inIconSpace {
            with(IconArt) {
                rotated(-12f, 50f, 50f) {
                    val phone = rr(32f, 10f, 36f, 70f, 8f)
                    shape(phone, Color.White, ink)
                    drawPath(rr(38f, 18f, 24f, 46f, 3f), ink.copy(alpha = 0.15f))
                    drawPath(circle(50f, 72f, 3f), ink)
                }
                for ((x, dir) in listOf(18f to -1f, 82f to 1f)) {
                    val a = path { moveTo(x, 34f); quadraticTo(x + dir * 14f, 50f, x, 66f) }
                    stroke(a, Color.White, 6f)
                }
            }
        }
    }
}

// MARK: - UI glyphs (close, check, arrows, trash, dots, star, send, people)

enum class GlyphKind { Close, Check, ArrowRight, Trash, More, Spin, Send, People, Star, Controller }

/**
 * A UI glyph in [color]. [size] is in design points and scales with the window; [weight] is the
 * stroke width in the 100pt space.
 */
@Composable
fun Glyph(kind: GlyphKind, size: Float = 16f, color: Color = Color.White, weight: Float = 16f, modifier: Modifier = Modifier) {
    val ink = Theme.ink
    Canvas(modifier.size(UI.s(size).dp)) {
        inIconSpace { with(IconArt) { drawGlyph(kind, color, weight, ink) } }
    }
}

private fun DrawScope.drawGlyph(kind: GlyphKind, color: Color, weight: Float, ink: Color) = with(IconArt) {
    val w = weight
    when (kind) {
        GlyphKind.Close -> {
            stroke(lineTo(22f, 22f, 78f, 78f), color, w)
            stroke(lineTo(78f, 22f, 22f, 78f), color, w)
        }
        GlyphKind.Check -> {
            val p = path { moveTo(18f, 54f); lineTo(40f, 76f); lineTo(84f, 26f) }
            stroke(p, color, w)
        }
        GlyphKind.ArrowRight -> {
            stroke(lineTo(14f, 50f, 82f, 50f), color, w)
            val p = path { moveTo(54f, 22f); lineTo(84f, 50f); lineTo(54f, 78f) }
            stroke(p, color, w)
        }
        GlyphKind.Trash -> {
            drawPath(rr(26f, 30f, 48f, 58f, 8f), color)
            drawPath(rr(16f, 18f, 68f, 12f, 5f), color)
            drawPath(rr(38f, 8f, 24f, 12f, 5f), color)
        }
        GlyphKind.More -> {
            for (x in floatArrayOf(22f, 50f, 78f)) drawPath(circle(x, 50f, 9f), color)
        }
        GlyphKind.Spin -> {
            // -150° to -30° over the top, 30° to 150° under the bottom: 120° sweeps each.
            val a = path { arcTo(Rect(20f, 20f, 80f, 80f), -150f, 120f, true) }
            val b = path { arcTo(Rect(20f, 20f, 80f, 80f), 30f, 120f, true) }
            stroke(a, color, w)
            stroke(b, color, w)
            drawPath(poly(76f to 20f, 92f to 44f, 64f to 44f), color)
            drawPath(poly(24f to 80f, 8f to 56f, 36f to 56f), color)
        }
        GlyphKind.Send -> {
            drawPath(poly(10f to 46f, 90f to 12f, 62f to 90f, 48f to 58f), color)
            stroke(lineTo(48f, 58f, 90f, 12f), ink.copy(alpha = 0.35f), 6f)
        }
        GlyphKind.People -> {
            drawPath(circle(34f, 32f, 15f), color)
            drawPath(circle(70f, 36f, 12f), color)
            drawPath(rr(8f, 52f, 52f, 36f, 18f), color)
            drawPath(rr(56f, 56f, 38f, 30f, 15f), color)
        }
        GlyphKind.Star -> {
            val p = path {
                for (i in 0 until 10) {
                    val r = if (i % 2 == 0) 44f else 19f
                    val a = i * PI / 5 - PI / 2
                    val x = (50 + r * cos(a)).toFloat()
                    val y = (52 + r * sin(a)).toFloat()
                    if (i == 0) moveTo(x, y) else lineTo(x, y)
                }
                close()
            }
            drawPath(p, color)
        }
        GlyphKind.Controller -> drawDeck("nerd", color, if (color == Color.White) ink else Color.White)
    }
}

// MARK: - Review sheet

/**
 * Every drawn icon on one sheet so the art can be reviewed at a glance: the deck icons on their
 * deck colours, then the crown, trophy, hand-off and UI glyphs. Mirrors the `IconSheet` in
 * `OlaBallTests/IconSheetTests.swift` minus the mascots, badge and crowns row, which live in Hud.kt.
 * Needs [Decks.load] to have run.
 */
@Composable
fun IconSheet() {
    Column(Modifier.background(Theme.night).padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Decks.all.chunked(6).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { deck ->
                        SheetCell(deck.color) {
                            DeckIcon(deck.id, fill = Color.White, ink = Art.darker(deck.color, 0.45f), modifier = Modifier.padding(18.dp))
                        }
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SheetCell(Theme.violet) { CrownIcon(size = 70f) }
            SheetCell(Theme.violet) { TrophyIcon(size = 80f) }
            SheetCell(Theme.violet) { HandoffIcon(size = 80f) }
            SheetCell(Theme.violet) {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Glyph(GlyphKind.Close, size = 18f); Glyph(GlyphKind.Check, size = 18f)
                        Glyph(GlyphKind.ArrowRight, size = 18f); Glyph(GlyphKind.Trash, size = 18f)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Glyph(GlyphKind.More, size = 18f); Glyph(GlyphKind.Spin, size = 18f)
                        Glyph(GlyphKind.Send, size = 18f); Glyph(GlyphKind.People, size = 18f)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Glyph(GlyphKind.Star, size = 18f); Glyph(GlyphKind.Controller, size = 18f)
                    }
                }
            }
        }
    }
}

/** One 96pt rounded tile of the sheet, content centred. */
@Composable
private fun SheetCell(color: Color, content: @Composable BoxScope.() -> Unit) {
    Box(Modifier.size(96.dp).background(color, RoundedCornerShape(16.dp)), contentAlignment = Alignment.Center, content = content)
}
