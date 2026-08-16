import AppKit

func makeIcon(pixels: Int, to path: String) {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("rep") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = 56 * size / 1024
    let corner = 232 * size / 1024
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let shapePath = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), xRadius: corner, yRadius: corner)

    if let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.08, green: 0.55, blue: 0.99, alpha: 1.0),
        NSColor(calibratedRed: 0.00, green: 0.74, blue: 0.84, alpha: 1.0)
    ]) {
        gradient.draw(in: shapePath, angle: -65)
    }

    let pointSize = 430 * size / 1024
    if let symbol = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: nil),
       let configured = symbol.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)) {
        let side = 470 * size / 1024
        let symbolRect = NSRect(x: (size - side) / 2, y: (size - side) / 2, width: side, height: side)
        configured.isTemplate = true
        NSColor.white.set()
        configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)
    }

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
}

let base = "Sources/Assets.xcassets/AppIcon.appiconset/"
let sizes: [(Int, String)] = [
    (16, "icon_16.png"),
    (32, "icon_32.png"),
    (64, "icon_64.png"),
    (128, "icon_128.png"),
    (256, "icon_256.png"),
    (512, "icon_512.png"),
    (1024, "icon_1024.png")
]
for (px, name) in sizes {
    makeIcon(pixels: px, to: base + name)
    print("Wrote \(name) (\(px)px)")
}
