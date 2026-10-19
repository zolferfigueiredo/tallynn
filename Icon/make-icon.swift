// App icon and menu bar icon: Tallinn's Viru Gate in white on Estonian blue fading to black.
// run.sh and build.sh run this: swift Icon/make-icon.swift <output folder>
// It writes <output>/AppIcon.iconset and the menu bar template <output>/menubar.png and menubar@2x.png.
import AppKit

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let blue = rgb(0x0072CE), black = rgb(0x05070B)

func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSBezierPath {
    NSBezierPath(rect: NSRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
}

/// A round tower's cone roof with slightly concave sides, overhanging the tower by a tenth of its width.
func cone(x: CGFloat, width w: CGFloat, top: CGFloat, height r: CGFloat) -> NSBezierPath {
    let eave = w * 0.1
    let path = NSBezierPath()
    path.move(to: NSPoint(x: x - eave, y: top))
    path.curve(to: NSPoint(x: x + w / 2, y: top + r), controlPoint1: NSPoint(x: x + w * 0.18, y: top + r * 0.25),
               controlPoint2: NSPoint(x: x + w * 0.42, y: top + r * 0.75))
    path.curve(to: NSPoint(x: x + w + eave, y: top), controlPoint1: NSPoint(x: x + w * 0.58, y: top + r * 0.75),
               controlPoint2: NSPoint(x: x + w * 0.82, y: top + r * 0.25))
    path.close()
    return path
}

/// The gate in one color on a 1024-unit canvas: two round towers with cone roofs and the crenellated gateway
/// between them, its base at y 200. The door is filled with `door`, or cut right through without one.
func gate(_ color: NSColor, door: NSColor? = nil) -> NSImage {
    NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
        color.setFill()
        let shape = rect(372, 200, 652, 500)
        var x: CGFloat = 372
        while x + 27.6 <= 652.5 {
            shape.append(rect(x, 500, x + 27.6, 525))
            x += 46
        }
        for left: CGFloat in [196, 636] {
            shape.append(rect(left, 200, left + 192, 610))
            shape.append(cone(x: left, width: 192, top: 610, height: 205))
        }
        shape.fill()
        let arch = rect(450, 200, 574, 392)
        arch.appendOval(in: NSRect(x: 450, y: 330, width: 124, height: 124))
        if let door { door.setFill() } else { NSGraphicsContext.current?.compositingOperation = .clear }
        arch.fill()
        return true
    }
}

/// The gate's extent on its canvas.
let gateBounds = NSRect(x: 176, y: 200, width: 672, height: 615)

/// Draws the gate scaled by `scale` about its centre line, its base at `base`.
func place(_ image: NSImage, scale: CGFloat, base: CGFloat) {
    let width = gateBounds.width * scale, height = gateBounds.height * scale
    image.draw(in: NSRect(x: 512 - width / 2, y: base, width: width, height: height), from: gateBounds,
               operation: .sourceOver, fraction: 1)
}

// Soft bevel from ClaudioStat: light glows in from the top edges and shade from the bottom ones.
func bevel(_ path: NSBezierPath, light: NSColor, dark: NSColor, blur: CGFloat, offset: CGFloat) {
    let away: CGFloat = 100_000
    for (color, dy) in [(dark, offset), (light, -offset)] {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let outside = NSBezierPath(rect: path.bounds.insetBy(dx: -4 * (blur + offset), dy: -4 * (blur + offset)))
        outside.append(path)
        outside.windingRule = .evenOdd
        outside.transform(using: AffineTransform(translationByX: away, byY: 0))
        let glow = NSShadow()
        glow.shadowColor = color
        glow.shadowOffset = NSSize(width: -away, height: dy)
        glow.shadowBlurRadius = blur
        glow.set()
        outside.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

func bitmap(_ width: Int, _ height: Int, _ draw: () -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

func icon(pixels: Int) -> Data {
    bitmap(pixels, pixels) {
        let s = CGFloat(pixels) / 1024
        // Shadows and bevels are in device space, so their sizes scale by hand.
        NSAffineTransform(transform: AffineTransform(scale: s)).concat()
        // macOS icon grid: an 824-unit rounded square centred in 1024.
        let plate = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
        NSGraphicsContext.saveGraphicsState()
        plate.addClip()
        NSGradient(colors: [black, rgb(0x003E73), blue])!.draw(in: plate, angle: 90)
        place(gate(.white, door: black), scale: 0.92, base: 100)  // standing on the bottom edge
        NSGraphicsContext.restoreGraphicsState()
        bevel(plate, light: NSColor(white: 1, alpha: 0.3), dark: NSColor(white: 0, alpha: 0.35), blur: 40 * s, offset: 14 * s)
    }
}

/// 18 points tall, as wide as the gate needs. The menu bar centres the image in its 22 points, and the numbers'
/// baseline sits 5.7 points up, so the gate is 14 points tall and starts 3.5 points up the image: its base on the
/// baseline, its walls as tall as the digits, only the roofs above.
func menuBar(scale: Int) -> Data {
    let s = CGFloat(scale), inner = 14 * s
    let width = (inner * gateBounds.width / gateBounds.height).rounded(.up)
    return bitmap(Int(width) + 2 * scale, 18 * scale) {
        gate(.black).draw(in: NSRect(x: s, y: 3.5 * s, width: width, height: inner), from: gateBounds,
                          operation: .sourceOver, fraction: 1)
    }
}

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = folder.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
// Nothing under 64 px: macOS 26 puts small drawn sizes on a grey plate, and scales the 64 px one down cleanly.
for points in [32, 128, 256, 512] {
    for scale in [1, 2] where points * scale >= 64 {
        try icon(pixels: points * scale).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"))
    }
}
try menuBar(scale: 1).write(to: folder.appendingPathComponent("menubar.png"))
try menuBar(scale: 2).write(to: folder.appendingPathComponent("menubar@2x.png"))
