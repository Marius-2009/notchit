import AppKit

let out = CommandLine.arguments[1]
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let fm = FileManager.default
try? fm.removeItem(atPath: out)
try fm.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.1
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let squircle = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGradient(starting: NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.2, alpha: 1),
               ending: NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1))!.draw(in: squircle, angle: -90)
    let w = body.width * 0.62, h = body.height * 0.3
    let island = NSRect(x: body.midX - w / 2, y: body.maxY - h - body.height * 0.14, width: w, height: h)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: island, xRadius: h / 2, yRadius: h / 2).fill()
    let d = h * 0.56
    let ring = NSRect(x: island.minX + h * 0.22, y: island.midY - d / 2, width: d, height: d)
    let orange = NSColor(calibratedRed: 1, green: 0.624, blue: 0.039, alpha: 1)
    let arc = NSBezierPath()
    arc.appendArc(withCenter: NSPoint(x: ring.midX, y: ring.midY), radius: d / 2 - d * 0.08, startAngle: 90, endAngle: -200, clockwise: true)
    arc.lineWidth = d * 0.16
    arc.lineCapStyle = .round
    orange.setStroke()
    arc.stroke()
    let green = NSColor(calibratedRed: 0.2, green: 0.84, blue: 0.42, alpha: 1)
    green.setFill()
    let bars: [CGFloat] = [0.45, 0.85, 0.6, 0.95]
    let bw = h * 0.1
    for (i, v) in bars.enumerated() {
        let bh = h * 0.5 * v
        let x = island.maxX - h * 0.25 - CGFloat(bars.count - i) * bw * 1.8
        NSBezierPath(roundedRect: NSRect(x: x, y: island.midY - bh / 2, width: bw, height: bh), xRadius: bw / 2, yRadius: bw / 2).fill()
    }
    let card = NSRect(x: body.minX + body.width * 0.16, y: body.minY + body.height * 0.16, width: body.width * 0.68, height: body.height * 0.26)
    NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
    NSBezierPath(roundedRect: card, xRadius: card.height * 0.3, yRadius: card.height * 0.3).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for p in sizes {
    let data = draw(p)
    if p <= 512 { try data.write(to: URL(fileURLWithPath: "\(out)/icon_\(p)x\(p).png")) }
    if p >= 32 { try data.write(to: URL(fileURLWithPath: "\(out)/icon_\(p / 2)x\(p / 2)@2x.png")) }
}
