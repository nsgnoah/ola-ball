import Testing
import SwiftUI
import UIKit
import ImageIO
@testable import OlaBall

/// Renders the App Store icon from the app's own palette and drawing style, so the icon and the
/// game can never drift apart. Run it and the 1024x1024 opaque PNG lands in build/app-icon.png;
/// review it, then copy it to OlaBall/Resources/Assets.xcassets/AppIcon.appiconset/icon.png.
///
/// This replaced scripts/make_icon.swift, which drew an old design and then silently produced a
/// solid black square: its "strip the alpha" step redrew into a fresh opaque bitmap and the redraw
/// failed, leaving the buffer's zeroed default. Every check at the time only confirmed the file was
/// 1024x1024 without alpha, which a black square passes.
@MainActor
struct AppIconTests {
    @Test func renderAppIcon() throws {
        let side: CGFloat = 1024
        let renderer = ImageRenderer(content: AppIconArt().frame(width: side, height: side))
        renderer.scale = 1
        let art = try #require(renderer.uiImage)

        // App Store icons must have NO alpha channel. UIKit's "opaque" renderer still exports
        // RGBA, so draw into a CGContext that has no alpha at all and encode from that.
        let w = Int(side), h = Int(side)
        let ctx = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.draw(try #require(art.cgImage), in: CGRect(x: 0, y: 0, width: w, height: h))
        let cg = try #require(ctx.makeImage())

        // Guard against exactly the failure that shipped the black icon: a blank render.
        #expect(cg.width == 1024 && cg.height == 1024)
        #expect(cg.alphaInfo == .noneSkipLast || cg.alphaInfo == .none, "the icon must not carry alpha")
        #expect(!Self.isSingleColour(cg), "the icon rendered as a single flat colour")

        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let out = repo.appendingPathComponent("build/app-icon.png")
        try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
        let dest = try #require(CGImageDestinationCreateWithURL(out as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(dest, cg, nil)
        #expect(CGImageDestinationFinalize(dest))
        print("APP ICON: \(out.path)")
    }

    /// Samples a grid of pixels; true if they are all the same colour.
    static func isSingleColour(_ image: CGImage) -> Bool {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var seen = Set<UInt32>()
        for y in stride(from: 0, to: h, by: 64) {
            for x in stride(from: 0, to: w, by: 64) {
                let i = (y * w + x) * 4
                seen.insert(UInt32(data[i]) << 16 | UInt32(data[i + 1]) << 8 | UInt32(data[i + 2]))
            }
        }
        return seen.count < 2
    }
}

/// The icon: a his-blue and her-pink prize wheel with a gold pointer, on the game-show backdrop.
/// The wheel is the "spin" in Spinola; the two colours are His World and Her World.
/// No lettering, because text is unreadable at home-screen size. Everything important sits inside
/// the middle 80%, since iOS masks the corners into a rounded square.
private struct AppIconArt: View {
    private let slices = 8

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width
            ZStack {
                // Backdrop: the same violet-toward-night the game uses, with sunburst rays.
                Theme.violet.mix(with: Theme.night, by: 0.30)
                Rays(count: 16)
                    .fill(.white.opacity(0.07))
                RadialGradient(colors: [.clear, Theme.night.opacity(0.55)],
                               center: .center, startRadius: s * 0.30, endRadius: s * 0.75)

                wheel(diameter: s * 0.70)
                    .rotationEffect(.degrees(-11))
                    .offset(y: s * 0.035)

                pointer(width: s * 0.17)
                    .offset(y: -s * 0.335)
            }
        }
    }

    private func wheel(diameter d: CGFloat) -> some View {
        let r = d / 2
        let sliceAngle = 360.0 / Double(slices)
        return ZStack {
            // Drop shadow, the sticker look used throughout the app.
            Circle().fill(Theme.ink.opacity(0.45)).offset(y: d * 0.035)
            // Rim.
            Circle().fill(.white)
            // Slices, alternating His and Her.
            ForEach(0..<slices, id: \.self) { i in
                Wedge(start: .degrees(Double(i) * sliceAngle - 90),
                      end: .degrees(Double(i + 1) * sliceAngle - 90))
                    .fill(i.isMultiple(of: 2) ? Theme.his : Theme.hers)
                    .padding(d * 0.055)
            }
            // White dividers between slices.
            ForEach(0..<slices, id: \.self) { i in
                Rectangle()
                    .fill(.white)
                    .frame(width: d * 0.018, height: r * 0.9)
                    .offset(y: -r * 0.45)
                    .rotationEffect(.degrees(Double(i) * sliceAngle))
            }
            // Ink outline.
            Circle().strokeBorder(Theme.ink, lineWidth: d * 0.022)
            // Hub: brass disc with a star, like the in-game wheel.
            ZStack {
                Circle().fill(Theme.goldDeep).offset(y: d * 0.012)
                Circle().fill(Theme.gold)
                Circle().strokeBorder(Theme.ink, lineWidth: d * 0.018)
                Star().fill(.white).padding(d * 0.075)
                Star().stroke(Theme.ink, lineWidth: d * 0.010).padding(d * 0.075)
            }
            .frame(width: d * 0.30, height: d * 0.30)
            .rotationEffect(.degrees(11))   // keep the star upright against the wheel's tilt
        }
        .frame(width: d, height: d)
    }

    private func pointer(width w: CGFloat) -> some View {
        ZStack {
            Triangle().fill(Theme.goldDeep).offset(y: w * 0.06)
            Triangle().fill(Theme.gold)
            Triangle().stroke(Theme.ink, style: StrokeStyle(lineWidth: w * 0.07, lineJoin: .round))
        }
        .frame(width: w, height: w * 0.92)
    }
}

private struct Wedge: Shape {
    let start: Angle, end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// A downward-pointing triangle.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Star: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.44
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = Double(i) * .pi / 5 - .pi / 2
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

private struct Rays: Shape {
    let count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height)
        let step = 2 * Double.pi / Double(count * 2)
        for i in stride(from: 0, to: count * 2, by: 2) {
            let a0 = Double(i) * step, a1 = a0 + step
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
            p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
            p.closeSubpath()
        }
        return p
    }
}
