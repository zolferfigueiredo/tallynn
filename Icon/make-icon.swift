// App icon and menu bar icon: Tallinn's Viru Gate, a download arrow passing through its arch.
// run.sh runs this: swift Icon/make-icon.swift <output folder>
// It writes <output>/AppIcon.iconset and the menu bar template <output>/menubar.png and menubar@2x.png.
import AppKit

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let sky = NSGradient(colors: [rgb(0xDDF3EE), rgb(0x7EC6DA), rgb(0x2B78AE)])!  // horizon first
let limestone = NSGradient(colors: [rgb(0xFFF8EA), rgb(0xEBDDC3), rgb(0xC4AE8B)])!
let roof = NSGradient(colors: [rgb(0xF47F52), rgb(0xCC4128), rgb(0x8E2618)])!
let gold = NSGradient(colors: [rgb(0xFFE08A), rgb(0xE9AE3A)])!
let slit = rgb(0x5E4B3A)

/// The menu bar template wants the shape alone: everything black, the arch cut out, windows left off.
var silhouette = false

func fill(_ path: NSBezierPath, _ gradient: NSGradient, angle: CGFloat = 0) {
    if silhouette { NSColor.black.setFill(); path.fill() } else { gradient.draw(in: path, angle: angle) }
}

func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> NSBezierPath {
    NSBezierPath(rect: NSRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
}

/// A round wall tower: limestone lit from the left, a red cone roof with slightly concave sides overhanging it.
func tower(x: CGFloat, width w: CGFloat, ground: CGFloat, top: CGFloat, roofHeight r: CGFloat) {
    fill(rect(x, ground, x + w, top), limestone)
    if !silhouette {
        NSColor(white: 0, alpha: 0.14).setFill()
        rect(x, top - 22, x + w, top).fill()  // the eave's shadow
        slit.setFill()
        for y in [top - 90, top - 195] {
            NSBezierPath(roundedRect: NSRect(x: x + w / 2 - 9, y: y - 46, width: 18, height: 46), xRadius: 9, yRadius: 9).fill()
        }
    }
    let eave = w * 0.1
    let cone = NSBezierPath()
    cone.move(to: NSPoint(x: x - eave, y: top))
    cone.curve(to: NSPoint(x: x + w / 2, y: top + r), controlPoint1: NSPoint(x: x + w * 0.18, y: top + r * 0.25),
               controlPoint2: NSPoint(x: x + w * 0.42, y: top + r * 0.75))
    cone.curve(to: NSPoint(x: x + w + eave, y: top), controlPoint1: NSPoint(x: x + w * 0.58, y: top + r * 0.75),
               controlPoint2: NSPoint(x: x + w * 0.82, y: top + r * 0.25))
    cone.close()
    fill(cone, roof)
}

/// The gate in 1024-unit icon space. In the silhouette the ground rises, keeping only the recognisable top.
func drawGate() {
    let ground: CGFloat = silhouette ? 200 : 60
    // The gateway wall with merlons, its arch, and the arrow passing through.
    let wall = rect(372, ground, 652, 500)
    var x: CGFloat = 372
    while x + 27.6 <= 652.5 {
        wall.append(rect(x, 500, x + 27.6, 525))
        x += 46
    }
    fill(wall, limestone, angle: -90)
    let opening = rect(450, ground, 574, 392)
    opening.appendOval(in: NSRect(x: 450, y: 330, width: 124, height: 124))
    NSGraphicsContext.saveGraphicsState()
    if silhouette { NSGraphicsContext.current?.compositingOperation = .clear }
    rgb(0x3B3552).setFill()
    opening.fill()
    NSGraphicsContext.restoreGraphicsState()
    let arrow = rect(496, 318, 528, 400)
    arrow.move(to: NSPoint(x: 458, y: 322))
    arrow.line(to: NSPoint(x: 566, y: 322))
    arrow.line(to: NSPoint(x: 512, y: 248))
    arrow.close()
    fill(arrow, gold, angle: -90)
    tower(x: 196, width: 192, ground: ground, top: 610, roofHeight: 205)
    tower(x: 636, width: 192, ground: ground, top: 610, roofHeight: 205)
}

/// The silhouette's extent in icon space, so the menu bar image can be fitted to it.
let silhouetteBounds = NSRect(x: 176, y: 200, width: 672, height: 615)

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
        sky.draw(in: plate, angle: 90)
        NSGraphicsContext.saveGraphicsState()
        plate.addClip()
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
        shadow.shadowBlurRadius = 22 * s
        shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
        shadow.set()
        drawGate()
        NSGraphicsContext.restoreGraphicsState()
        bevel(plate, light: NSColor(white: 1, alpha: 0.4), dark: NSColor(white: 0, alpha: 0.25), blur: 40 * s, offset: 14 * s)
    }
}

/// 18 points tall, as wide as the gate needs, with a point of air above and below.
func menuBar(scale: Int) -> Data {
    let height = 18 * scale, inner = CGFloat(16 * scale)
    let width = Int((inner * silhouetteBounds.width / silhouetteBounds.height).rounded(.up)) + 2 * scale
    return bitmap(width, height) {
        silhouette = true
        var transform = AffineTransform(translationByX: CGFloat(scale), byY: CGFloat(scale))
        transform.scale(inner / silhouetteBounds.height)
        transform.translate(x: -silhouetteBounds.minX, y: -silhouetteBounds.minY)
        NSAffineTransform(transform: transform).concat()
        drawGate()
        silhouette = false
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
