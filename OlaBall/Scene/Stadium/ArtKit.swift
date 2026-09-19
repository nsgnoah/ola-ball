import SceneKit
import UIKit
import SwiftUI

/// Palette, materials, and procedurally generated textures for the stadium renderer.
/// Everything is generated at runtime with Core Graphics: no image assets, nothing from the network.
enum Art {
    // MARK: Palette

    static let skyZenith = UIColor(red: 0.015, green: 0.02, blue: 0.06, alpha: 1)
    static let skyHorizon = UIColor(red: 0.09, green: 0.15, blue: 0.30, alpha: 1)
    static let turfLight = UIColor(red: 0.15, green: 0.46, blue: 0.25, alpha: 1)
    static let turfDark = UIColor(red: 0.12, green: 0.40, blue: 0.21, alpha: 1)
    static let paint = UIColor(red: 0.97, green: 0.97, blue: 0.94, alpha: 1)
    static let gold = UIColor(red: 0.98, green: 0.80, blue: 0.28, alpha: 1)
    static let scrimmageBlue = UIColor(red: 0.25, green: 0.62, blue: 1.0, alpha: 1)
    static let firstDownYellow = UIColor(red: 1.0, green: 0.92, blue: 0.25, alpha: 1)
    static let steel = UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
    static let skinTones: [UIColor] = [
        UIColor(red: 0.95, green: 0.80, blue: 0.68, alpha: 1),
        UIColor(red: 0.87, green: 0.68, blue: 0.53, alpha: 1),
        UIColor(red: 0.72, green: 0.52, blue: 0.38, alpha: 1),
        UIColor(red: 0.55, green: 0.38, blue: 0.27, alpha: 1),
        UIColor(red: 0.40, green: 0.27, blue: 0.19, alpha: 1),
    ]

    // MARK: Materials

    static func pbr(_ color: UIColor, roughness: CGFloat = 0.65, metalness: CGFloat = 0.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    static func textured(_ image: UIImage, roughness: CGFloat = 0.8, repeatX: CGFloat = 1, repeatY: CGFloat = 1) -> SCNMaterial {
        let m = pbr(.white, roughness: roughness)
        m.diffuse.contents = image
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(repeatX), Float(repeatY), 1)
        return m
    }

    static func glow(_ color: UIColor, strength: CGFloat = 1.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = strength
        return m
    }

    static func sprite(_ image: UIImage, additive: Bool = true) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = image
        m.emission.contents = image
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.blendMode = additive ? .add : .alpha
        return m
    }

    // MARK: Colors

    static func color(_ c: UIColor, brightness delta: CGFloat, saturation sDelta: CGFloat = 0) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: min(1, max(0, s + sDelta)), brightness: min(1, max(0, b + delta)), alpha: a)
    }

    /// SwiftUI color shifted in brightness (for tiles and gradients).
    static func swiftUI(_ c: Color, brightness delta: CGFloat) -> Color {
        Color(color(UIColor(c), brightness: delta))
    }

    static func luminance(_ c: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    /// White or near-black, whichever reads on this color.
    static func trim(for c: UIColor) -> UIColor {
        luminance(c) > 0.55 ? UIColor(white: 0.08, alpha: 1) : .white
    }

    // MARK: Texture cache

    private static var cache: [String: UIImage] = [:]
    private static func cached(_ key: String, _ make: () -> UIImage) -> UIImage {
        if let img = cache[key] { return img }
        let img = make()
        cache[key] = img
        return img
    }

    // MARK: Sky (equirectangular, also used as the lighting environment)

    static func skyImage() -> UIImage {
        cached("sky") {
            let size = CGSize(width: 1024, height: 512)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                let colors = [skyZenith.cgColor, skyZenith.cgColor, skyHorizon.cgColor, UIColor(red: 0.16, green: 0.20, blue: 0.30, alpha: 1).cgColor, UIColor(red: 0.05, green: 0.06, blue: 0.08, alpha: 1).cgColor] as CFArray
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 0.5, 0.53, 1])!
                c.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                // Stars in the upper half
                var rng = SeededRNG(seed: 7)
                for _ in 0..<900 {
                    let x = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.width
                    let y = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.height * 0.46
                    let r = CGFloat(Float.random(in: 0.4...1.6, using: &rng))
                    let a = CGFloat(Float.random(in: 0.25...0.9, using: &rng))
                    c.setFillColor(UIColor(white: 1, alpha: a).cgColor)
                    c.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
                }
                // Stadium light haze at the horizon
                let haze = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(red: 0.55, green: 0.65, blue: 0.9, alpha: 0.35).cgColor, UIColor.clear.cgColor] as CFArray, locations: [0, 1])!
                c.drawRadialGradient(haze, startCenter: CGPoint(x: size.width / 2, y: size.height * 0.5), startRadius: 0, endCenter: CGPoint(x: size.width / 2, y: size.height * 0.5), endRadius: size.width * 0.5, options: [])
            }
        }
    }

    // MARK: Grass

    /// The playing surface without team art: 65.3 yd across (x in -32.65...32.65) by 132 yd (z in -16...116).
    /// Image row 0 is z = -16 (the near end): the plane's top edge lands at world -z after its rotation.
    /// Screen "up" is world +z and screen "right" is world -x, so glyphs are drawn rotated 180° to read from the camera.
    static let grassPixelsPerYard: CGFloat = 14
    static let grassWidthYards: CGFloat = CGFloat(Field.width) + 12
    static let grassLengthYards: CGFloat = 132

    static func grassImage() -> UIImage {
        cached("grass") {
            let ppy = grassPixelsPerYard
            let size = CGSize(width: grassWidthYards * ppy, height: grassLengthYards * ppy)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                func px(_ x: CGFloat) -> CGFloat { (x + grassWidthYards / 2) * ppy }
                func pz(_ z: CGFloat) -> CGFloat { (z + 16) * ppy }
                let halfW = CGFloat(Field.halfWidth)

                // Apron outside the field
                c.setFillColor(UIColor(red: 0.10, green: 0.30, blue: 0.18, alpha: 1).cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                // Mow stripes, 5 yards each, across the whole 120
                for i in stride(from: -10, to: 110, by: 5) {
                    c.setFillColor(((i / 5) % 2 == 0) ? turfLight.cgColor : turfDark.cgColor)
                    c.fill(CGRect(x: px(-halfW), y: pz(CGFloat(i)), width: halfW * 2 * ppy, height: 5 * ppy))
                }
                // Grain
                var rng = SeededRNG(seed: 11)
                for _ in 0..<14000 {
                    let x = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.width
                    let y = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.height
                    let light = Float.random(in: 0..<1, using: &rng) > 0.7
                    c.setFillColor((light ? UIColor.white : UIColor.black).withAlphaComponent(light ? 0.025 : 0.045).cgColor)
                    c.fill(CGRect(x: x, y: y, width: CGFloat(Float.random(in: 1...3, using: &rng)), height: CGFloat(Float.random(in: 1...6, using: &rng))))
                }
                // Worn strip between the hashes
                c.setFillColor(UIColor(red: 0.35, green: 0.30, blue: 0.15, alpha: 0.10).cgColor)
                c.fill(CGRect(x: px(-CGFloat(Field.hashX) - 1), y: pz(15), width: (CGFloat(Field.hashX) + 1) * 2 * ppy, height: 70 * ppy))

                // Sideline borders (6 ft solid) and end lines
                c.setFillColor(paint.cgColor)
                c.fill(CGRect(x: px(-halfW - 2), y: pz(-10), width: 2 * ppy, height: 120 * ppy))
                c.fill(CGRect(x: px(halfW), y: pz(-10), width: 2 * ppy, height: 120 * ppy))
                c.fill(CGRect(x: px(-halfW - 2), y: pz(-10) - 0.4 * ppy, width: (halfW + 2) * 2 * ppy, height: 0.4 * ppy))
                c.fill(CGRect(x: px(-halfW - 2), y: pz(110), width: (halfW + 2) * 2 * ppy, height: 0.4 * ppy))

                // Yard lines
                c.setStrokeColor(paint.cgColor)
                c.setLineWidth(0.12 * ppy)
                for yard in stride(from: 0, through: 100, by: 5) {
                    c.move(to: CGPoint(x: px(-halfW), y: pz(CGFloat(yard))))
                    c.addLine(to: CGPoint(x: px(halfW), y: pz(CGFloat(yard))))
                }
                c.strokePath()
                c.setLineWidth(0.22 * ppy)
                for yard in [0, 50, 100] {
                    c.move(to: CGPoint(x: px(-halfW), y: pz(CGFloat(yard))))
                    c.addLine(to: CGPoint(x: px(halfW), y: pz(CGFloat(yard))))
                }
                c.strokePath()
                // Hash marks every yard, inside hashes and at the sidelines
                c.setLineWidth(0.1 * ppy)
                for yard in 1..<100 where yard % 5 != 0 {
                    for hx in [-CGFloat(Field.hashX), CGFloat(Field.hashX), -halfW + 0.4, halfW - 0.4] {
                        c.move(to: CGPoint(x: px(hx - 0.33), y: pz(CGFloat(yard))))
                        c.addLine(to: CGPoint(x: px(hx + 0.33), y: pz(CGFloat(yard))))
                    }
                }
                c.strokePath()

                // Numbers with arrows, reading from their own sideline
                let numAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 2.3 * ppy, weight: .heavy), .foregroundColor: paint.withAlphaComponent(0.95)]
                for yard in stride(from: 10, through: 90, by: 10) {
                    let n = yard <= 50 ? yard : 100 - yard
                    let str = NSAttributedString(string: "\(n)", attributes: numAttrs)
                    for side: CGFloat in [-1, 1] {
                        let x = px(side * (halfW - 9))
                        let y = pz(CGFloat(yard))
                        c.saveGState()
                        c.translateBy(x: x, y: y)
                        c.rotate(by: side < 0 ? -.pi / 2 : .pi / 2)
                        str.draw(at: CGPoint(x: -str.size().width / 2, y: -str.size().height / 2))
                        c.restoreGState()
                        if yard != 50 {
                            let dir: CGFloat = yard < 50 ? -1 : 1
                            let ay = y + dir * 1.9 * ppy
                            c.setFillColor(paint.withAlphaComponent(0.9).cgColor)
                            c.move(to: CGPoint(x: x, y: ay + dir * 0.6 * ppy))
                            c.addLine(to: CGPoint(x: x - 0.35 * ppy, y: ay - dir * 0.2 * ppy))
                            c.addLine(to: CGPoint(x: x + 0.35 * ppy, y: ay - dir * 0.2 * ppy))
                            c.closePath()
                            c.fillPath()
                        }
                    }
                }
            }
        }
    }

    /// A team's painted end zone: 53.3 yd across by 10 deep, with the wordmark reading from the camera.
    /// `goalLineAtTop` is true for the far end zone (its goal line is the row nearest z = 100).
    static func endZoneImage(team: Team, goalLineAtTop: Bool) -> UIImage {
        cached("endzone-\(team.id)-\(goalLineAtTop)") {
            let ppy = grassPixelsPerYard
            let size = CGSize(width: CGFloat(Field.width) * ppy, height: 10 * ppy)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                let base = UIColor(team.color)
                c.setFillColor(color(base, brightness: -0.08).cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
                c.setLineWidth(0.6 * ppy)
                var d: CGFloat = -20
                while d < CGFloat(Field.width) + 20 {
                    c.move(to: CGPoint(x: d * ppy, y: 0))
                    c.addLine(to: CGPoint(x: (d + 10) * ppy, y: 10 * ppy))
                    d += 2.5
                }
                c.strokePath()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 6.2 * ppy, weight: .black),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                    .strokeColor: color(base, brightness: -0.35),
                    .strokeWidth: -3.0,
                ]
                let str = NSAttributedString(string: team.name.uppercased(), attributes: attrs)
                c.saveGState()
                c.translateBy(x: size.width / 2, y: size.height / 2)
                c.rotate(by: .pi)
                str.draw(at: CGPoint(x: -str.size().width / 2, y: -str.size().height / 2))
                c.restoreGState()
                // Goal line along the inner edge
                c.setFillColor(paint.cgColor)
                c.fill(CGRect(x: 0, y: goalLineAtTop ? 0 : size.height - 0.22 * ppy, width: size.width, height: 0.22 * ppy))
            }
        }
    }

    /// Midfield crest: a ring with the home team's mark.
    static func crestImage(team: Team) -> UIImage {
        cached("crest-\(team.id)") {
            let ppy = grassPixelsPerYard
            let size = CGSize(width: 12 * ppy, height: 12 * ppy)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                let cx = size.width / 2, cy = size.height / 2
                c.setFillColor(color(UIColor(team.color), brightness: -0.05).withAlphaComponent(0.9).cgColor)
                c.fillEllipse(in: CGRect(x: cx - 4.5 * ppy, y: cy - 4.5 * ppy, width: 9 * ppy, height: 9 * ppy))
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
                c.setLineWidth(0.35 * ppy)
                c.strokeEllipse(in: CGRect(x: cx - 5 * ppy, y: cy - 5 * ppy, width: 10 * ppy, height: 10 * ppy))
                let mark = NSAttributedString(string: team.monogram, attributes: [.font: UIFont.systemFont(ofSize: 6.5 * ppy, weight: .black), .foregroundColor: UIColor.white.withAlphaComponent(0.92)])
                c.saveGState()
                c.translateBy(x: cx, y: cy)
                c.rotate(by: .pi)
                mark.draw(at: CGPoint(x: -mark.size().width / 2, y: -mark.size().height / 2))
                c.restoreGState()
            }
        }
    }

    // MARK: Crowd, wall, glow, ball, confetti, tags

    static func crowdImage() -> UIImage {
        cached("crowd") {
            let size = CGSize(width: 512, height: 256)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1).cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                var rng = SeededRNG(seed: 3)
                let rows = 7
                let rowH = size.height / CGFloat(rows)
                for row in 0..<rows {
                    let y = CGFloat(row) * rowH
                    // Rows nearer the field (bottom of the image) catch more light.
                    let light = 0.55 + 0.45 * CGFloat(row) / CGFloat(rows - 1)
                    c.setFillColor(UIColor(white: 0.10, alpha: 1).cgColor)
                    c.fill(CGRect(x: 0, y: y + rowH - 6, width: size.width, height: 6))   // seat back / step
                    var x: CGFloat = CGFloat(Float.random(in: 0..<10, using: &rng))
                    while x < size.width {
                        let w = CGFloat(Float.random(in: 18...26, using: &rng))
                        if Float.random(in: 0..<1, using: &rng) < 0.12 { x += w; continue }   // empty seat
                        // Muted fan colors: mostly dark clothes with the occasional bright jersey
                        let bright = Float.random(in: 0..<1, using: &rng) < 0.10
                        let hue = CGFloat(Float.random(in: 0..<1, using: &rng))
                        let sat = bright ? CGFloat(Float.random(in: 0.35...0.6, using: &rng)) : CGFloat(Float.random(in: 0.05...0.25, using: &rng))
                        let bri = (bright ? CGFloat(Float.random(in: 0.45...0.7, using: &rng)) : CGFloat(Float.random(in: 0.14...0.38, using: &rng))) * light
                        c.setFillColor(UIColor(hue: hue, saturation: sat, brightness: bri, alpha: 1).cgColor)
                        c.addPath(UIBezierPath(roundedRect: CGRect(x: x, y: y + 12, width: w, height: rowH - 16), cornerRadius: w * 0.3).cgPath)
                        c.fillPath()
                        let skin = skinTones[Int(Float.random(in: 0..<Float(skinTones.count), using: &rng))]
                        c.setFillColor(color(skin, brightness: -(1 - light) * 0.5).cgColor)
                        c.fillEllipse(in: CGRect(x: x + w * 0.25, y: y + 2, width: w * 0.5, height: w * 0.5))
                        x += w + CGFloat(Float.random(in: 2...6, using: &rng))
                    }
                }
            }
        }
    }

    static func wallImage() -> UIImage {
        cached("wall") {
            let size = CGSize(width: 1024, height: 96)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1).cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 44, weight: .black), .foregroundColor: gold.withAlphaComponent(0.85)]
                let str = NSAttributedString(string: "OLA BALL   ·   CALL THE SHOTS   ·   ", attributes: attrs)
                var x: CGFloat = 8
                while x < size.width { str.draw(at: CGPoint(x: x, y: 24)); x += str.size().width }
            }
        }
    }

    static func glowSprite() -> UIImage {
        cached("glow") {
            let size = CGSize(width: 256, height: 256)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 1, alpha: 0.95).cgColor, UIColor(white: 1, alpha: 0.35).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 0.25, 1])!
                ctx.cgContext.drawRadialGradient(grad, startCenter: CGPoint(x: 128, y: 128), startRadius: 0, endCenter: CGPoint(x: 128, y: 128), endRadius: 128, options: [])
            }
        }
    }

    static func shadowSprite() -> UIImage {
        cached("shadow") {
            let size = CGSize(width: 128, height: 128)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [UIColor(white: 0, alpha: 0.55).cgColor, UIColor(white: 0, alpha: 0.25).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray, locations: [0, 0.5, 1])!
                ctx.cgContext.drawRadialGradient(grad, startCenter: CGPoint(x: 64, y: 64), startRadius: 0, endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
            }
        }
    }

    static func ballImage() -> UIImage {
        cached("ball") {
            let size = CGSize(width: 256, height: 128)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(UIColor(red: 0.50, green: 0.27, blue: 0.14, alpha: 1).cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                // pebble grain
                var rng = SeededRNG(seed: 5)
                for _ in 0..<1400 {
                    let x = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.width
                    let y = CGFloat(Float.random(in: 0..<1, using: &rng)) * size.height
                    c.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
                    c.fillEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                }
                // white stripes near the ends and the laces along the top seam
                c.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor)
                c.fill(CGRect(x: 40, y: 0, width: 8, height: size.height))
                c.fill(CGRect(x: 208, y: 0, width: 8, height: size.height))
                c.fill(CGRect(x: 96, y: 8, width: 64, height: 5))
                for i in 0..<7 { c.fill(CGRect(x: 100 + i * 9, y: 2, width: 3, height: 16)) }
            }
        }
    }

    static func confettiSprite() -> UIImage {
        cached("confetti") {
            UIGraphicsImageRenderer(size: CGSize(width: 16, height: 10)).image { ctx in
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 16, height: 10))
            }
        }
    }

    static func dashImage() -> UIImage {
        cached("dash") {
            UIGraphicsImageRenderer(size: CGSize(width: 64, height: 16)).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(UIColor(white: 1, alpha: 0.25).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 64, height: 16))
                c.setFillColor(UIColor.white.cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 36, height: 16))
            }
        }
    }

    /// Jersey number square, drawn once per number and color combination.
    static func numberImage(_ n: Int, jersey: UIColor, ink: UIColor) -> UIImage {
        cached("num-\(n)-\(jersey.hashValue)") {
            let size = CGSize(width: 256, height: 256)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                c.setFillColor(jersey.cgColor)
                c.fill(CGRect(origin: .zero, size: size))
                // Shoulder yoke stripe
                c.setFillColor(ink.withAlphaComponent(0.25).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: 256, height: 22))
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 150, weight: .heavy), .foregroundColor: ink, .strokeColor: color(jersey, brightness: -0.3), .strokeWidth: -2.5]
                let str = NSAttributedString(string: "\(n)", attributes: attrs)
                str.draw(at: CGPoint(x: (size.width - str.size().width) / 2, y: (size.height - str.size().height) / 2 + 6))
            }
        }
    }

    /// Small floating tag: rounded dark pill with a role abbreviation.
    static func tagImage(_ text: String, tint: UIColor) -> UIImage {
        cached("tag-\(text)-\(tint.hashValue)") {
            let size = CGSize(width: 160, height: 64)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                let c = ctx.cgContext
                let rect = CGRect(x: 4, y: 4, width: 152, height: 56)
                c.setFillColor(UIColor(white: 0.05, alpha: 0.82).cgColor)
                c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 28).cgPath)
                c.fillPath()
                c.setStrokeColor(tint.withAlphaComponent(0.9).cgColor)
                c.setLineWidth(4)
                c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 28).cgPath)
                c.strokePath()
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .heavy), .foregroundColor: UIColor.white]
                let str = NSAttributedString(string: text, attributes: attrs)
                str.draw(at: CGPoint(x: (size.width - str.size().width) / 2, y: (size.height - str.size().height) / 2))
            }
        }
    }
}
