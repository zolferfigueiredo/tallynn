// DMG window background: the icon's Estonian blue fading to black, with a curved arrow from the app (left) to the
// Applications link (right). Positions must match the Finder script in build.sh.
// build.sh runs this: swift Icon/make-dmg-background.swift <output folder>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width: CGFloat = 640, height: CGFloat = 400
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: srgb, components: [r / 255, g / 255, b / 255, a])!
}

func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: srgb, colors: stops.map(\.0) as CFArray, locations: stops.map(\.1))!
}

func draw(scale: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                        bytesPerRow: 0, space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Flip to y-down, as in ClaudioStat's.
    ctx.translateBy(x: 0, y: height * scale)
    ctx.scaleBy(x: scale, y: -scale)

    // Mid blue down to where the icon labels sit, black only below them, so the labels stay readable.
    ctx.drawLinearGradient(gradient([(rgb(26, 134, 224), 0), (rgb(0, 114, 206), 0.45), (rgb(0, 62, 115), 0.8),
                                     (rgb(5, 7, 11), 1)]),
                           start: CGPoint(x: width / 2, y: 0), end: CGPoint(x: width / 2, y: height), options: [])
    // A soft light from the top left, like the icon plate's bevel.
    ctx.saveGState()
    ctx.translateBy(x: 0.1 * width, y: 0)
    ctx.scaleBy(x: 0.6 * width, y: 0.6 * height)
    ctx.drawRadialGradient(gradient([(rgb(255, 255, 255, 0.18), 0), (rgb(255, 255, 255, 0), 1)]),
                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
    ctx.restoreGState()

    // Curved arrow over the gap between the two 128 pt icons centred at (160, 190) and (480, 190).
    let from = CGPoint(x: 236, y: 176), control = CGPoint(x: 320, y: 92), to = CGPoint(x: 402, y: 172)
    let angle = atan2(to.y - control.y, to.x - control.x), head: CGFloat = 20, spread: CGFloat = 0.5
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 3), blur: 8, color: rgb(5, 7, 11, 0.45))
    ctx.setStrokeColor(rgb(236, 240, 245, 0.95))
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: from)
    ctx.addQuadCurve(to: to, control: control)
    ctx.move(to: CGPoint(x: to.x - head * cos(angle - spread), y: to.y - head * sin(angle - spread)))
    ctx.addLine(to: to)
    ctx.addLine(to: CGPoint(x: to.x - head * cos(angle + spread), y: to.y - head * sin(angle + spread)))
    ctx.strokePath()
    ctx.restoreGState()

    return ctx.makeImage()!
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for (scale, name) in [(1, "background.png"), (2, "background@2x.png")] as [(CGFloat, String)] {
    let dest = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,
                                               UTType.png.identifier as CFString, 1, nil)!
    let dpi = 72 * scale
    CGImageDestinationAddImage(dest, draw(scale: scale),
                               [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(name)") }
}
