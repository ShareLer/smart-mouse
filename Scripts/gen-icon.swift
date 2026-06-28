#!/usr/bin/env swift
import AppKit

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/sm_icon_out"
let iconsetDir = "\(outDir)/AppIcon.iconset"

try? FileManager.default.removeItem(atPath: iconsetDir)
try FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func makeIcon(size: CGFloat, path: String, scale: Int = 1) {
    let s = size * CGFloat(scale)
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let img = NSImage(size: rect.size, flipped: false) { _ in
        let inset = s * 0.04
        let bg = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                               xRadius: s * 0.22, yRadius: s * 0.22)
        // Flat blue gradient base
        NSColor(red: 0.23, green: 0.47, blue: 0.96, alpha: 1.0).setFill()
        bg.fill()
        // Inner lighter circle
        let inner = NSBezierPath(ovalIn: rect.insetBy(dx: s * 0.18, dy: s * 0.18))
        NSColor(red: 0.31, green: 0.55, blue: 0.98, alpha: 1.0).setFill()
        inner.fill()
        // Arrow cursor
        let cx = s / 2; let cy = s / 2; let w = s * 0.22
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: cx - w * 0.7, y: cy - w * 0.35))
        cursor.line(to: NSPoint(x: cx - w * 0.2, y: cy + w * 0.55))
        cursor.line(to: NSPoint(x: cx - w * 0.05, y: cy + w * 0.18))
        cursor.line(to: NSPoint(x: cx + w * 0.5, y: cy + w * 0.72))
        cursor.line(to: NSPoint(x: cx + w * 0.72, y: cy - w * 0.28))
        cursor.close()
        NSColor.white.setFill()
        cursor.fill()
        // Sparkle dots
        let dots: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.45, -0.55, w * 0.15),
            (0.55, -0.42, w * 0.12),
            (0.48, 0.52, w * 0.10),
            (-0.50, 0.38, w * 0.12),
        ]
        for (dx, dy, r) in dots {
            NSColor(white: 1, alpha: 0.7).setFill()
            let dot = NSBezierPath(ovalIn: NSRect(x: cx + dx * w - r, y: cy + dy * w - r,
                                                   width: r * 2, height: r * 2))
            dot.fill()
        }
        return true
    }
    guard let tiff = img.tiffRepresentation,
          let bmp = NSBitmapImageRep(data: tiff),
          let png = bmp.representation(using: .png, properties: [:])
    else { fputs("  failed size=\(size) scale=\(scale)\n", stderr); return }
    try? png.write(to: URL(fileURLWithPath: path))
}

let sizes: [(CGFloat, String)] = [
    (16, "16x16"), (16, "16x16@2x"),
    (32, "32x32"), (32, "32x32@2x"),
    (128, "128x128"), (128, "128x128@2x"),
    (256, "256x256"), (256, "256x256@2x"),
    (512, "512x512"), (512, "512x512@2x"),
]
let scales: [String: Int] = ["16x16@2x": 2, "32x32@2x": 2, "128x128@2x": 2, "256x256@2x": 2, "512x512@2x": 2]

for (size, name) in sizes {
    let s = scales[name] ?? 1
    let p = "\(iconsetDir)/icon_\(name).png"
    makeIcon(size: size, path: p, scale: s)
    fputs(".", stderr)
}
fputs("\n", stderr)

// Create .icns
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetDir, "-o", "\(outDir)/AppIcon.icns"]
task.launch()
task.waitUntilExit()
fputs("Icon generated: \(outDir)/AppIcon.icns\n", stderr)
