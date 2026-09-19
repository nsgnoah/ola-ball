// Renders the 1024x1024 App Store icon. Run: swift scripts/make_icon.swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, 1])! }

// Background: night-sky navy to field green gradient
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0.043, 0.071, 0.125), rgb(0.18, 0.49, 0.31)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])

// Yard lines
ctx.setStrokeColor(CGColor(colorSpace: cs, components: [1, 1, 1, 0.18])!)
ctx.setLineWidth(10)
for i in 1..<8 {
    let y = CGFloat(i) * CGFloat(size) / 8 * 0.55
    ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: CGFloat(size), y: y)); ctx.strokePath()
}

// Football
ctx.saveGState()
ctx.translateBy(x: 512, y: 540)
ctx.rotate(by: -.pi / 7)
let ball = CGRect(x: -330, y: -200, width: 660, height: 400)
ctx.setFillColor(rgb(0.55, 0.30, 0.16))
ctx.fillEllipse(in: ball)
ctx.setStrokeColor(rgb(0.30, 0.16, 0.08))
ctx.setLineWidth(18)
ctx.strokeEllipse(in: ball)
// Laces
ctx.setStrokeColor(rgb(1, 1, 1))
ctx.setLineCap(.round)
ctx.setLineWidth(22)
ctx.move(to: CGPoint(x: -150, y: 0)); ctx.addLine(to: CGPoint(x: 150, y: 0)); ctx.strokePath()
for x in stride(from: -100, through: 100, by: 50) {
    ctx.move(to: CGPoint(x: CGFloat(x), y: -40)); ctx.addLine(to: CGPoint(x: CGFloat(x), y: 40)); ctx.strokePath()
}
ctx.restoreGState()

// Gold accent stripe at the bottom (the "call" bar)
ctx.setFillColor(rgb(0.961, 0.773, 0.259))
ctx.fill(CGRect(x: 160, y: 130, width: 704, height: 44))

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png")
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(url.path)")
