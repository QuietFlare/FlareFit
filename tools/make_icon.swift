// Renders a FlareFit dumbbell app icon (1024x1024 PNG). Custom shapes only.
// arg1 = output path, arg2 = "arc" to include the timer ring (else no ring).
import AppKit
import ImageIO

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let withArc = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "arc"

let px = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext
let size = CGFloat(px)

// Background: deep ember diagonal gradient
let bgColors = [
    NSColor(calibratedRed: 1.00, green: 0.45, blue: 0.10, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.85, green: 0.16, blue: 0.05, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.10, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 0.55, 1.0])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

// Optional timer arc: white ring open at the top-right
if withArc {
    ctx.saveGState()
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    ctx.setLineWidth(52)
    ctx.setLineCap(.round)
    let center = CGPoint(x: size / 2, y: size / 2)
    ctx.addArc(center: center, radius: 350, startAngle: .pi / 3,
               endAngle: .pi / 3 + 2 * .pi * 5 / 6, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
}

// --- Dumbbell (centered, horizontal), built from rounded rectangles ---
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}
func dumbbell() -> CGPath {
    let p = CGMutablePath()
    p.addPath(rrect(368, 484, 288, 56, 28))      // handle
    p.addPath(rrect(340, 442, 44, 140, 20))      // left inner collar
    p.addPath(rrect(640, 442, 44, 140, 20))      // right inner collar
    p.addPath(rrect(292, 400, 58, 224, 26))      // left outer plate
    p.addPath(rrect(674, 400, 58, 224, 26))      // right outer plate
    return p
}

// Soft shadow behind the whole shape
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40,
              color: NSColor.black.withAlphaComponent(0.30).cgColor)
ctx.addPath(dumbbell())
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

// Subtle vertical gradient fill (crisp white top → soft cream bottom)
ctx.saveGState()
ctx.addPath(dumbbell())
ctx.clip()
let fill = [
    NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1).cgColor,
    NSColor(calibratedRed: 1.00, green: 0.92, blue: 0.82, alpha: 1).cgColor,
] as CFArray
let fillGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fill, locations: [0, 1])!
ctx.drawLinearGradient(fillGrad, start: CGPoint(x: 512, y: 624), end: CGPoint(x: 512, y: 400), options: [])
ctx.restoreGState()

gctx.flushGraphics()

// Flatten to opaque RGB (no alpha) — App Store icons must not have an alpha
// channel. Redraw into a noneSkipLast context (the supported "no alpha" 32-bit
// format), then encode; the background is fully opaque, so this is lossless.
let rendered = rep.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let flat = CGContext(
    data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
flat.draw(rendered, in: CGRect(x: 0, y: 0, width: size, height: size))
let outImage = flat.makeImage()!

let url = URL(fileURLWithPath: outPath)
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, outImage, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(outPath)")
