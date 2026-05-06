import AppKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/ZenTap.iconset")
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let sizes: [(Int, Int, String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

func drawIcon(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let canvas = NSRect(x: 0, y: 0, width: side, height: side)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = side * 0.055
    let baseRect = canvas.insetBy(dx: inset, dy: inset)
    let base = NSBezierPath(roundedRect: baseRect, xRadius: side * 0.19, yRadius: side * 0.19)
    NSColor(calibratedRed: 0.965, green: 0.945, blue: 0.895, alpha: 1).setFill()
    base.fill()

    let edge = NSBezierPath(roundedRect: baseRect.insetBy(dx: side * 0.014, dy: side * 0.014), xRadius: side * 0.17, yRadius: side * 0.17)
    NSColor(calibratedWhite: 0.08, alpha: 0.12).setStroke()
    edge.lineWidth = max(1, side * 0.012)
    edge.stroke()

    let center = NSPoint(x: side * 0.5, y: side * 0.53)
    let radius = side * 0.265

    let moss = NSBezierPath(ovalIn: NSRect(x: center.x - radius * 1.16, y: center.y - radius * 1.16, width: radius * 2.32, height: radius * 2.32))
    NSColor(calibratedRed: 0.38, green: 0.47, blue: 0.36, alpha: 0.12).setFill()
    moss.fill()

    let enso = NSBezierPath()
    enso.appendArc(withCenter: center, radius: radius, startAngle: 18, endAngle: 322, clockwise: false)
    NSColor(calibratedRed: 0.10, green: 0.095, blue: 0.08, alpha: 0.86).setStroke()
    enso.lineWidth = max(2, side * 0.045)
    enso.lineCapStyle = .round
    enso.stroke()

    let accent = NSBezierPath()
    accent.appendArc(withCenter: center, radius: radius * 0.985, startAngle: 330, endAngle: 26, clockwise: false)
    NSColor(calibratedRed: 0.58, green: 0.14, blue: 0.08, alpha: 0.90).setStroke()
    accent.lineWidth = max(2, side * 0.044)
    accent.lineCapStyle = .round
    accent.stroke()

    let micColor = NSColor(calibratedRed: 0.10, green: 0.095, blue: 0.08, alpha: 0.88)
    micColor.setStroke()
    let micBody = NSBezierPath(roundedRect: NSRect(x: center.x - side * 0.055, y: center.y - side * 0.035, width: side * 0.11, height: side * 0.18), xRadius: side * 0.055, yRadius: side * 0.055)
    micBody.lineWidth = max(1.25, side * 0.018)
    micBody.stroke()

    let micStem = NSBezierPath()
    micStem.move(to: NSPoint(x: center.x, y: center.y - side * 0.13))
    micStem.line(to: NSPoint(x: center.x, y: center.y - side * 0.06))
    micStem.move(to: NSPoint(x: center.x - side * 0.075, y: center.y - side * 0.14))
    micStem.line(to: NSPoint(x: center.x + side * 0.075, y: center.y - side * 0.14))
    micStem.lineWidth = max(1.25, side * 0.018)
    micStem.lineCapStyle = .round
    micStem.stroke()

    let characterRect = NSRect(x: side * 0.27, y: side * 0.12, width: side * 0.46, height: side * 0.16)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: side * 0.11, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.13, green: 0.11, blue: 0.08, alpha: 0.76),
        .paragraphStyle: paragraph
    ]
    "指言".draw(in: characterRect, withAttributes: attributes)

    image.unlockFocus()
    return image
}

for (pointSize, scale, filename) in sizes {
    let pixelSide = pointSize * scale
    let image = drawIcon(side: CGFloat(pixelSide))
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        fatalError("Unable to render \(filename)")
    }
    try png.write(to: outputURL.appendingPathComponent(filename))
}
