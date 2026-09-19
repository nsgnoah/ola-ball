// Renders the 1024x1024 App Store icon (no alpha): a paper card with "HIS / HER" in condensed type.
import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
// Paper
ctx.setFillColor(NSColor(red: 0.957, green: 0.937, blue: 0.894, alpha: 1).cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
// Two-tone diagonal: his (cobalt) top-left, hers (rosewood) bottom-right
let his = NSColor(red: 0.122, green: 0.247, blue: 0.561, alpha: 1)
let hers = NSColor(red: 0.690, green: 0.196, blue: 0.361, alpha: 1)
ctx.setFillColor(his.cgColor)
ctx.move(to: CGPoint(x: 0, y: 1024)); ctx.addLine(to: CGPoint(x: 1024, y: 1024)); ctx.addLine(to: CGPoint(x: 0, y: 0)); ctx.closePath(); ctx.fillPath()
ctx.setFillColor(hers.cgColor)
ctx.move(to: CGPoint(x: 1024, y: 1024)); ctx.addLine(to: CGPoint(x: 1024, y: 0)); ctx.addLine(to: CGPoint(x: 0, y: 0)); ctx.closePath(); ctx.fillPath()
// Paper seam
ctx.setStrokeColor(NSColor(red: 0.957, green: 0.937, blue: 0.894, alpha: 1).cgColor)
ctx.setLineWidth(28)
ctx.move(to: CGPoint(x: 0, y: 0)); ctx.addLine(to: CGPoint(x: 1024, y: 1024)); ctx.strokePath()
func draw(_ text: String, size fs: CGFloat, at p: CGPoint, color: NSColor) {
    let font = NSFont(name: "Futura-CondensedExtraBold", size: fs) ?? NSFont.boldSystemFont(ofSize: fs)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let s = NSAttributedString(string: text, attributes: attrs)
    s.draw(at: CGPoint(x: p.x - s.size().width / 2, y: p.y - s.size().height / 2))
}
draw("HIS", size: 300, at: CGPoint(x: 300, y: 690), color: .white)
draw("HER", size: 300, at: CGPoint(x: 724, y: 330), color: .white)
image.unlockFocus()
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
rep.hasAlpha = false
let png = rep.representation(using: .png, properties: [:])!
// Strip alpha by drawing onto an opaque bitmap
let opaque = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: opaque)
NSImage(data: png)!.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! opaque.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
