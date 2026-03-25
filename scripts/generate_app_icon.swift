import AppKit
import Foundation

let outputPath = "/Users/woody/workspace/local-paste/assets/AppIcon-1024.png"
let side: CGFloat = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

let image = NSImage(size: canvas.size)
image.lockFocus()

NSColor.clear.setFill()
canvas.fill()

let baseRect = canvas.insetBy(dx: 64, dy: 64)
let rounded = NSBezierPath(roundedRect: baseRect, xRadius: 220, yRadius: 220)

if let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.97, green: 0.44, blue: 0.15, alpha: 1.0),
    NSColor(calibratedRed: 0.95, green: 0.22, blue: 0.36, alpha: 1.0),
    NSColor(calibratedRed: 0.27, green: 0.18, blue: 0.72, alpha: 1.0)
]) {
    gradient.draw(in: rounded, angle: -35)
}

let glowRect = baseRect.insetBy(dx: 80, dy: 80)
let glow = NSBezierPath(roundedRect: glowRect, xRadius: 150, yRadius: 150)
NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
glow.fill()

let boardRect = NSRect(
    x: baseRect.midX - 210,
    y: baseRect.midY - 225,
    width: 420,
    height: 470
)
let board = NSBezierPath(roundedRect: boardRect, xRadius: 54, yRadius: 54)
NSColor(calibratedWhite: 1.0, alpha: 0.97).setFill()
board.fill()

let clipTop = NSRect(
    x: baseRect.midX - 98,
    y: boardRect.maxY - 46,
    width: 196,
    height: 66
)
let clipPath = NSBezierPath(roundedRect: clipTop, xRadius: 28, yRadius: 28)
NSColor(calibratedWhite: 0.89, alpha: 1.0).setFill()
clipPath.fill()

let lineColor = NSColor(calibratedRed: 0.26, green: 0.32, blue: 0.45, alpha: 0.9)
for idx in 0..<5 {
    let y = boardRect.maxY - 120 - CGFloat(idx) * 72
    let w = idx == 2 ? 250.0 : 300.0
    let lineRect = NSRect(x: baseRect.midX - w / 2, y: y, width: w, height: 24)
    let line = NSBezierPath(roundedRect: lineRect, xRadius: 12, yRadius: 12)
    lineColor.withAlphaComponent(0.18).setFill()
    line.fill()
}

let accentRect = NSRect(x: boardRect.minX + 34, y: boardRect.minY + 38, width: 150, height: 32)
let accent = NSBezierPath(roundedRect: accentRect, xRadius: 16, yRadius: 16)
NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.23, alpha: 1.0).setFill()
accent.fill()

let dot = NSBezierPath(ovalIn: NSRect(x: boardRect.maxX - 72, y: boardRect.minY + 38, width: 32, height: 32))
NSColor(calibratedRed: 0.24, green: 0.69, blue: 0.97, alpha: 1.0).setFill()
dot.fill()

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    print("Generated \(outputPath)")
} catch {
    fputs("Failed to write icon: \\(error)\n", stderr)
    exit(1)
}
