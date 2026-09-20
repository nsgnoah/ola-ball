import SwiftUI

/// Every icon in the game is drawn here from primitives, in one sticker style:
/// a light fill with a rounded ink outline and a few ink details. Nothing from SF Symbols.
struct DeckIcon: View {
    let deck: Deck
    var fill: Color = .white
    var ink: Color = Theme.ink

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 100
            ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            IconArt.draw(deck.id, in: &ctx, fill: fill, ink: ink)
        }
    }
}

enum IconArt {
    static let line: CGFloat = 5.5

    static func stroke(_ ctx: inout GraphicsContext, _ p: Path, _ ink: Color, width: CGFloat = line) {
        ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    static func shape(_ ctx: inout GraphicsContext, _ p: Path, fill: Color, ink: Color) {
        ctx.fill(p, with: .color(fill))
        stroke(&ctx, p, ink)
    }

    static func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    }

    static func lineTo(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> Path {
        var p = Path(); p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1)); return p
    }

    static func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        guard let f = pts.first else { return p }
        p.move(to: CGPoint(x: f.0, y: f.1))
        for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.closeSubpath()
        return p
    }

    /// Run `body` with the context rotated around a pivot.
    static func rotated(_ ctx: inout GraphicsContext, degrees: Double, about pivot: CGPoint, _ body: (inout GraphicsContext) -> Void) {
        var c = ctx
        c.translateBy(x: pivot.x, y: pivot.y)
        c.rotate(by: .degrees(degrees))
        c.translateBy(x: -pivot.x, y: -pivot.y)
        body(&c)
    }

    static func draw(_ id: String, in ctx: inout GraphicsContext, fill: Color, ink: Color) {
        switch id {
        case "skincare": skincare(&ctx, fill, ink)
        case "fashion": fashion(&ctx, fill, ink)
        case "romcoms": romcoms(&ctx, fill, ink)
        case "reality": reality(&ctx, fill, ink)
        case "divas": divas(&ctx, fill, ink)
        case "weddings": weddings(&ctx, fill, ink)
        case "bookclub": bookclub(&ctx, fill, ink)
        case "wellness": wellness(&ctx, fill, ink)
        case "gossip": gossip(&ctx, fill, ink)
        case "football": football(&ctx, fill, ink)
        case "ballsports": ballsports(&ctx, fill, ink)
        case "cars": cars(&ctx, fill, ink)
        case "grill": grill(&ctx, fill, ink)
        case "nerd": nerd(&ctx, fill, ink)
        case "gear": gear(&ctx, fill, ink)
        case "actionmovies": actionmovies(&ctx, fill, ink)
        case "tech": tech(&ctx, fill, ink)
        case "fightnight": fightnight(&ctx, fill, ink)
        default: shape(&ctx, circle(50, 50, 30), fill: fill, ink: ink)
        }
    }

    // MARK: Her World

    /// Serum dropper with a drop beside it.
    static func skincare(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        shape(&c, rr(30, 38, 40, 54, 10), fill: fill, ink: ink)
        shape(&c, rr(43, 26, 14, 14, 3), fill: fill, ink: ink)
        shape(&c, Path(ellipseIn: CGRect(x: 36, y: 6, width: 28, height: 24)), fill: fill, ink: ink)
        c.fill(rr(40, 58, 20, 14, 3), with: .color(ink))
        var d = Path()
        d.move(to: CGPoint(x: 82, y: 50))
        d.addQuadCurve(to: CGPoint(x: 90, y: 66), control: CGPoint(x: 88, y: 56))
        d.addArc(center: CGPoint(x: 82, y: 66), radius: 8, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        d.addQuadCurve(to: CGPoint(x: 82, y: 50), control: CGPoint(x: 76, y: 56))
        d.closeSubpath()
        shape(&c, d, fill: fill, ink: ink)
    }

    /// Handbag with a clasp.
    static func fashion(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var handle = Path()
        handle.move(to: CGPoint(x: 34, y: 44))
        handle.addQuadCurve(to: CGPoint(x: 66, y: 44), control: CGPoint(x: 50, y: 4))
        stroke(&c, handle, ink, width: 6)
        var b = Path()
        b.move(to: CGPoint(x: 20, y: 44))
        b.addLine(to: CGPoint(x: 80, y: 44))
        b.addQuadCurve(to: CGPoint(x: 86, y: 90), control: CGPoint(x: 86, y: 66))
        b.addQuadCurve(to: CGPoint(x: 14, y: 90), control: CGPoint(x: 50, y: 96))
        b.addQuadCurve(to: CGPoint(x: 20, y: 44), control: CGPoint(x: 14, y: 66))
        b.closeSubpath()
        shape(&c, b, fill: fill, ink: ink)
        c.fill(Path(ellipseIn: CGRect(x: 43, y: 48, width: 14, height: 9)), with: .color(ink))
        stroke(&c, lineTo((20, 60), (80, 60)), ink, width: 3)
    }

    /// Heart with an arrow through it.
    static func romcoms(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var h = Path()
        h.move(to: CGPoint(x: 50, y: 90))
        h.addCurve(to: CGPoint(x: 10, y: 40), control1: CGPoint(x: 25, y: 78), control2: CGPoint(x: 5, y: 60))
        h.addCurve(to: CGPoint(x: 50, y: 30), control1: CGPoint(x: 14, y: 16), control2: CGPoint(x: 44, y: 14))
        h.addCurve(to: CGPoint(x: 90, y: 40), control1: CGPoint(x: 56, y: 14), control2: CGPoint(x: 86, y: 16))
        h.addCurve(to: CGPoint(x: 50, y: 90), control1: CGPoint(x: 95, y: 60), control2: CGPoint(x: 75, y: 78))
        h.closeSubpath()
        shape(&c, h, fill: fill, ink: ink)
        stroke(&c, lineTo((16, 86), (84, 16)), ink, width: 5)
        c.fill(poly([(86, 14), (70, 18), (82, 30)]), with: .color(ink))
        stroke(&c, lineTo((16, 86), (22, 72)), ink, width: 4)
        stroke(&c, lineTo((16, 86), (30, 80)), ink, width: 4)
    }

    /// A rose on a stem.
    static func reality(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var stem = Path()
        stem.move(to: CGPoint(x: 50, y: 94))
        stem.addQuadCurve(to: CGPoint(x: 50, y: 56), control: CGPoint(x: 57, y: 76))
        stroke(&c, stem, ink, width: 5)
        rotated(&c, degrees: 35, about: CGPoint(x: 66, y: 74)) { cc in
            shape(&cc, Path(ellipseIn: CGRect(x: 54, y: 68, width: 24, height: 12)), fill: fill, ink: ink)
        }
        shape(&c, circle(50, 36, 22), fill: fill, ink: ink)
        var petal = Path()
        petal.addArc(center: CGPoint(x: 50, y: 36), radius: 12, startAngle: .degrees(20), endAngle: .degrees(240), clockwise: false)
        stroke(&c, petal, ink, width: 4)
        var inner = Path()
        inner.addArc(center: CGPoint(x: 51, y: 35), radius: 5, startAngle: .degrees(200), endAngle: .degrees(60), clockwise: false)
        stroke(&c, inner, ink, width: 4)
    }

    /// Stage microphone.
    static func divas(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        shape(&c, rr(42, 56, 16, 36, 8), fill: fill, ink: ink)
        c.fill(rr(46, 66, 8, 5, 2), with: .color(ink))
        shape(&c, rr(36, 50, 28, 9, 4), fill: fill, ink: ink)
        let head = circle(50, 32, 23)
        shape(&c, head, fill: fill, ink: ink)
        var grid = c
        grid.clip(to: head)
        for y: CGFloat in [24, 32, 40] { stroke(&grid, lineTo((22, y), (78, y)), ink, width: 3.5) }
        for x: CGFloat in [40, 50, 60] { stroke(&grid, lineTo((x, 8), (x, 56)), ink, width: 3.5) }
    }

    /// Diamond ring.
    static func weddings(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var band = circle(50, 62, 26)
        band.addPath(circle(50, 62, 16))
        c.fill(band, with: .color(fill), style: FillStyle(eoFill: true))
        stroke(&c, circle(50, 62, 26), ink)
        stroke(&c, circle(50, 62, 16), ink)
        let gem = poly([(50, 6), (68, 24), (50, 44), (32, 24)])
        shape(&c, gem, fill: fill, ink: ink)
        stroke(&c, lineTo((34, 24), (66, 24)), ink, width: 3.5)
        stroke(&c, lineTo((42, 24), (50, 42)), ink, width: 3)
        stroke(&c, lineTo((58, 24), (50, 42)), ink, width: 3)
    }

    /// Open book.
    static func bookclub(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var l = Path()
        l.move(to: CGPoint(x: 12, y: 26))
        l.addQuadCurve(to: CGPoint(x: 50, y: 34), control: CGPoint(x: 31, y: 22))
        l.addLine(to: CGPoint(x: 50, y: 88))
        l.addQuadCurve(to: CGPoint(x: 12, y: 80), control: CGPoint(x: 31, y: 76))
        l.closeSubpath()
        var r = Path()
        r.move(to: CGPoint(x: 88, y: 26))
        r.addQuadCurve(to: CGPoint(x: 50, y: 34), control: CGPoint(x: 69, y: 22))
        r.addLine(to: CGPoint(x: 50, y: 88))
        r.addQuadCurve(to: CGPoint(x: 88, y: 80), control: CGPoint(x: 69, y: 76))
        r.closeSubpath()
        shape(&c, l, fill: fill, ink: ink)
        shape(&c, r, fill: fill, ink: ink)
        for (i, y) in [42.0, 53.0, 64.0].enumerated() {
            let w: CGFloat = i == 2 ? 14 : 20
            stroke(&c, lineTo((20, CGFloat(y)), (20 + w, CGFloat(y) + 3)), ink, width: 3)
            stroke(&c, lineTo((80, CGFloat(y)), (80 - w, CGFloat(y) + 3)), ink, width: 3)
        }
    }

    /// Lotus over water.
    static func wellness(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        let petal = Path(ellipseIn: CGRect(x: 39, y: 18, width: 22, height: 58))
        for deg in [-38.0, 38.0] {
            rotated(&c, degrees: deg, about: CGPoint(x: 50, y: 76)) { cc in shape(&cc, petal, fill: fill, ink: ink) }
        }
        shape(&c, petal, fill: fill, ink: ink)
        var water = Path()
        water.move(to: CGPoint(x: 14, y: 86))
        water.addQuadCurve(to: CGPoint(x: 86, y: 86), control: CGPoint(x: 50, y: 100))
        stroke(&c, water, ink, width: 5)
    }

    /// Sunglasses.
    static func gossip(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        stroke(&c, lineTo((10, 46), (2, 36)), ink, width: 5)
        stroke(&c, lineTo((90, 46), (98, 36)), ink, width: 5)
        stroke(&c, lineTo((45, 46), (55, 46)), ink, width: 5)
        for x: CGFloat in [8, 54] {
            let lens = rr(x, 36, 38, 30, 13)
            shape(&c, lens, fill: fill, ink: ink)
            var tint = c
            tint.clip(to: lens)
            tint.fill(Path(CGRect(x: x, y: 50, width: 38, height: 16)), with: .color(ink))
            stroke(&tint, lineTo((x + 8, 60), (x + 14, 54)), fill, width: 3)
        }
    }

    // MARK: His World

    /// Football with laces.
    static func football(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        rotated(&c, degrees: -25, about: CGPoint(x: 50, y: 50)) { cc in
            // Cubic curves on purpose: a closed pair of quad curves doesn't fill in Canvas.
            var b = Path()
            b.move(to: CGPoint(x: 8, y: 50))
            b.addCurve(to: CGPoint(x: 92, y: 50), control1: CGPoint(x: 28, y: 12), control2: CGPoint(x: 72, y: 12))
            b.addCurve(to: CGPoint(x: 8, y: 50), control1: CGPoint(x: 72, y: 88), control2: CGPoint(x: 28, y: 88))
            b.closeSubpath()
            shape(&cc, b, fill: fill, ink: ink)
            stroke(&cc, lineTo((34, 50), (66, 50)), ink, width: 4)
            for x: CGFloat in [40, 48, 56, 62] { stroke(&cc, lineTo((x, 44), (x, 56)), ink, width: 4) }
            stroke(&cc, lineTo((20, 36), (24, 64)), ink, width: 4)
            stroke(&cc, lineTo((80, 36), (76, 64)), ink, width: 4)
        }
    }

    /// Basketball.
    static func ballsports(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        let ball = circle(50, 50, 40)
        shape(&c, ball, fill: fill, ink: ink)
        var seams = c
        seams.clip(to: ball)
        stroke(&seams, lineTo((50, 8), (50, 92)), ink, width: 4)
        stroke(&seams, lineTo((8, 50), (92, 50)), ink, width: 4)
        stroke(&seams, circle(-4, 50, 46), ink, width: 4)
        stroke(&seams, circle(104, 50, 46), ink, width: 4)
    }

    /// Car, side view.
    static func cars(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        var b = Path()
        b.move(to: CGPoint(x: 8, y: 70))
        b.addLine(to: CGPoint(x: 8, y: 56))
        b.addQuadCurve(to: CGPoint(x: 22, y: 50), control: CGPoint(x: 10, y: 50))
        b.addLine(to: CGPoint(x: 34, y: 34))
        b.addQuadCurve(to: CGPoint(x: 42, y: 30), control: CGPoint(x: 36, y: 30))
        b.addLine(to: CGPoint(x: 60, y: 30))
        b.addQuadCurve(to: CGPoint(x: 70, y: 34), control: CGPoint(x: 66, y: 30))
        b.addLine(to: CGPoint(x: 82, y: 50))
        b.addQuadCurve(to: CGPoint(x: 92, y: 56), control: CGPoint(x: 90, y: 50))
        b.addLine(to: CGPoint(x: 92, y: 70))
        b.addQuadCurve(to: CGPoint(x: 86, y: 74), control: CGPoint(x: 92, y: 74))
        b.addLine(to: CGPoint(x: 14, y: 74))
        b.addQuadCurve(to: CGPoint(x: 8, y: 70), control: CGPoint(x: 8, y: 74))
        b.closeSubpath()
        shape(&c, b, fill: fill, ink: ink)
        c.fill(poly([(32, 50), (41, 37), (61, 37), (69, 50)]), with: .color(ink))
        c.fill(Path(CGRect(x: 48, y: 37, width: 4, height: 13)), with: .color(fill))
        for x: CGFloat in [28, 72] {
            c.fill(circle(x, 72, 10), with: .color(ink))
            c.fill(circle(x, 72, 4), with: .color(fill))
        }
    }

    /// Kettle grill.
    static func grill(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        stroke(&c, lineTo((36, 72), (30, 94)), ink, width: 5)
        stroke(&c, lineTo((64, 72), (70, 94)), ink, width: 5)
        shape(&c, circle(50, 44, 32), fill: fill, ink: ink)
        stroke(&c, lineTo((18, 44), (82, 44)), ink, width: 5)
        c.fill(rr(41, 4, 18, 9, 4), with: .color(ink))
        var flame = Path()
        flame.move(to: CGPoint(x: 50, y: 52))
        flame.addQuadCurve(to: CGPoint(x: 58, y: 64), control: CGPoint(x: 60, y: 54))
        flame.addQuadCurve(to: CGPoint(x: 42, y: 64), control: CGPoint(x: 50, y: 74))
        flame.addQuadCurve(to: CGPoint(x: 50, y: 52), control: CGPoint(x: 40, y: 54))
        flame.closeSubpath()
        c.fill(flame, with: .color(ink))
    }

    /// Game controller.
    static func nerd(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        shape(&c, circle(26, 62, 16), fill: fill, ink: ink)
        shape(&c, circle(74, 62, 16), fill: fill, ink: ink)
        let body = rr(8, 30, 84, 40, 20)
        c.fill(body, with: .color(fill))
        stroke(&c, body, ink)
        c.fill(rr(24, 42, 8, 22, 2.5), with: .color(ink))
        c.fill(rr(17, 49, 22, 8, 2.5), with: .color(ink))
        for (x, y) in [(68.0, 42.0), (77.0, 51.0), (59.0, 51.0), (68.0, 60.0)] { c.fill(circle(CGFloat(x), CGFloat(y), 4.5), with: .color(ink)) }
    }

    /// Hammer, tilted.
    static func gear(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        rotated(&c, degrees: -35, about: CGPoint(x: 50, y: 50)) { cc in
            shape(&cc, rr(45, 30, 10, 62, 5), fill: fill, ink: ink)
            shape(&cc, rr(28, 10, 44, 22, 6), fill: fill, ink: ink)
            cc.fill(rr(28, 10, 12, 22, 4), with: .color(ink))
        }
    }

    /// Clapperboard.
    static func actionmovies(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        shape(&c, rr(12, 44, 76, 44, 6), fill: fill, ink: ink)
        stroke(&c, lineTo((22, 60), (78, 60)), ink, width: 3)
        stroke(&c, lineTo((22, 72), (60, 72)), ink, width: 3)
        rotated(&c, degrees: -14, about: CGPoint(x: 14, y: 44)) { cc in
            let bar = rr(12, 26, 76, 18, 4)
            shape(&cc, bar, fill: fill, ink: ink)
            var s = cc
            s.clip(to: bar)
            for x: CGFloat in [20, 40, 60, 80] { stroke(&s, lineTo((x, 22), (x - 10, 48)), ink, width: 7) }
        }
        c.fill(circle(16, 44, 4.5), with: .color(ink))
    }

    /// Microchip.
    static func tech(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        for v: CGFloat in [36, 50, 64] {
            stroke(&c, lineTo((v, 26), (v, 14)), ink, width: 5)
            stroke(&c, lineTo((v, 74), (v, 86)), ink, width: 5)
            stroke(&c, lineTo((26, v), (14, v)), ink, width: 5)
            stroke(&c, lineTo((74, v), (86, v)), ink, width: 5)
        }
        shape(&c, rr(26, 26, 48, 48, 7), fill: fill, ink: ink)
        c.fill(rr(40, 40, 20, 20, 4), with: .color(ink))
        c.fill(circle(50, 50, 3.5), with: .color(fill))
    }

    /// Boxing glove.
    static func fightnight(_ c: inout GraphicsContext, _ fill: Color, _ ink: Color) {
        shape(&c, circle(27, 58, 13), fill: fill, ink: ink)
        shape(&c, rr(22, 12, 56, 62, 26), fill: fill, ink: ink)
        shape(&c, rr(34, 70, 44, 20, 6), fill: fill, ink: ink)
        stroke(&c, lineTo((40, 80), (72, 80)), ink, width: 3)
        stroke(&c, lineTo((52, 30), (64, 30)), ink, width: 4)
        stroke(&c, lineTo((52, 40), (64, 40)), ink, width: 4)
    }
}

// MARK: - Game glyphs (crown, trophy, phone, close)

struct CrownIcon: View {
    var filled = true
    var size: CGFloat = 18
    var empty: Color = Theme.ink.opacity(0.18)

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 100
            ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            let p = IconArt.poly([(12, 82), (12, 34), (32, 52), (50, 18), (68, 52), (88, 34), (88, 82)])
            if filled {
                ctx.fill(p, with: .color(Theme.gold))
                IconArt.stroke(&ctx, p, Theme.goldDeep, width: 7)
                for x: CGFloat in [30, 50, 70] { ctx.fill(IconArt.circle(x, 68, 5), with: .color(Theme.goldDeep)) }
            } else {
                IconArt.stroke(&ctx, p, empty, width: 7)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TrophyIcon: View {
    var size: CGFloat = 76

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 100
            ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            var l = Path(); l.move(to: CGPoint(x: 28, y: 22)); l.addQuadCurve(to: CGPoint(x: 28, y: 48), control: CGPoint(x: 4, y: 36))
            var r = Path(); r.move(to: CGPoint(x: 72, y: 22)); r.addQuadCurve(to: CGPoint(x: 72, y: 48), control: CGPoint(x: 96, y: 36))
            IconArt.stroke(&ctx, l, Theme.goldDeep, width: 7)
            IconArt.stroke(&ctx, r, Theme.goldDeep, width: 7)
            var cup = Path()
            cup.move(to: CGPoint(x: 26, y: 12)); cup.addLine(to: CGPoint(x: 74, y: 12)); cup.addLine(to: CGPoint(x: 74, y: 40))
            cup.addQuadCurve(to: CGPoint(x: 50, y: 64), control: CGPoint(x: 74, y: 62))
            cup.addQuadCurve(to: CGPoint(x: 26, y: 40), control: CGPoint(x: 26, y: 62))
            cup.closeSubpath()
            IconArt.shape(&ctx, cup, fill: Theme.gold, ink: Theme.goldDeep)
            IconArt.shape(&ctx, IconArt.rr(44, 62, 12, 14, 3), fill: Theme.gold, ink: Theme.goldDeep)
            IconArt.shape(&ctx, IconArt.rr(30, 76, 40, 12, 4), fill: Theme.gold, ink: Theme.goldDeep)
            ctx.fill(IconArt.poly([(50, 24), (56, 36), (50, 46), (44, 36)]), with: .color(Theme.goldDeep))
        }
        .frame(width: size, height: size)
    }
}

/// Two phones passing: the hand-off glyph.
struct HandoffIcon: View {
    var size: CGFloat = 80
    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 100
            ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            IconArt.rotated(&ctx, degrees: -12, about: CGPoint(x: 50, y: 50)) { c in
                let phone = IconArt.rr(32, 10, 36, 70, 8)
                IconArt.shape(&c, phone, fill: .white, ink: Theme.ink)
                c.fill(IconArt.rr(38, 18, 24, 46, 3), with: .color(Theme.ink.opacity(0.15)))
                c.fill(IconArt.circle(50, 72, 3), with: .color(Theme.ink))
            }
            for (x, dir) in [(18.0, -1.0), (82.0, 1.0)] {
                var a = Path(); a.move(to: CGPoint(x: x, y: 34)); a.addQuadCurve(to: CGPoint(x: x, y: 66), control: CGPoint(x: x + dir * 14, y: 50))
                IconArt.stroke(&ctx, a, .white, width: 6)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - UI glyphs (close, check, arrows, trash, dots, star, send, people)

enum GlyphKind { case close, check, arrowRight, trash, more, spin, send, people, star, controller }

struct Glyph: View {
    let kind: GlyphKind
    var size: CGFloat = 16
    var color: Color = .white
    var weight: CGFloat = 16   // stroke width in the 100pt space

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 100
            ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            draw(&ctx)
        }
        .frame(width: size, height: size)
    }

    private func draw(_ c: inout GraphicsContext) {
        let w = weight
        switch kind {
        case .close:
            IconArt.stroke(&c, IconArt.lineTo((22, 22), (78, 78)), color, width: w)
            IconArt.stroke(&c, IconArt.lineTo((78, 22), (22, 78)), color, width: w)
        case .check:
            var p = Path(); p.move(to: CGPoint(x: 18, y: 54)); p.addLine(to: CGPoint(x: 40, y: 76)); p.addLine(to: CGPoint(x: 84, y: 26))
            IconArt.stroke(&c, p, color, width: w)
        case .arrowRight:
            IconArt.stroke(&c, IconArt.lineTo((14, 50), (82, 50)), color, width: w)
            var p = Path(); p.move(to: CGPoint(x: 54, y: 22)); p.addLine(to: CGPoint(x: 84, y: 50)); p.addLine(to: CGPoint(x: 54, y: 78))
            IconArt.stroke(&c, p, color, width: w)
        case .trash:
            c.fill(IconArt.rr(26, 30, 48, 58, 8), with: .color(color))
            c.fill(IconArt.rr(16, 18, 68, 12, 5), with: .color(color))
            c.fill(IconArt.rr(38, 8, 24, 12, 5), with: .color(color))
        case .more:
            for x: CGFloat in [22, 50, 78] { c.fill(IconArt.circle(x, 50, 9), with: .color(color)) }
        case .spin:
            var a = Path(); a.addArc(center: CGPoint(x: 50, y: 50), radius: 30, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false)
            var b = Path(); b.addArc(center: CGPoint(x: 50, y: 50), radius: 30, startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
            IconArt.stroke(&c, a, color, width: w)
            IconArt.stroke(&c, b, color, width: w)
            c.fill(IconArt.poly([(76, 20), (92, 44), (64, 44)]), with: .color(color))
            c.fill(IconArt.poly([(24, 80), (8, 56), (36, 56)]), with: .color(color))
        case .send:
            c.fill(IconArt.poly([(10, 46), (90, 12), (62, 90), (48, 58)]), with: .color(color))
            IconArt.stroke(&c, IconArt.lineTo((48, 58), (90, 12)), Theme.ink.opacity(0.35), width: 6)
        case .people:
            c.fill(IconArt.circle(34, 32, 15), with: .color(color))
            c.fill(IconArt.circle(70, 36, 12), with: .color(color))
            c.fill(IconArt.rr(8, 52, 52, 36, 18), with: .color(color))
            c.fill(IconArt.rr(56, 56, 38, 30, 15), with: .color(color))
        case .star:
            var p = Path()
            for i in 0..<10 {
                let r: CGFloat = i % 2 == 0 ? 44 : 19
                let a = Double(i) * .pi / 5 - .pi / 2
                let pt = CGPoint(x: 50 + r * cos(a), y: 52 + r * sin(a))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            c.fill(p, with: .color(color))
        case .controller:
            IconArt.nerd(&c, color, color == .white ? Theme.ink : .white)
        }
    }
}
