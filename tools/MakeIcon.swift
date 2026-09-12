import AppKit

// Generates build/icon.iconset + SwiftPad.icns from a drawn icon.
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let inset = rect.insetBy(dx: 100, dy: 100)
let path = NSBezierPath(roundedRect: inset, xRadius: 210, yRadius: 210)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.36, green: 0.33, blue: 0.92, alpha: 1),
    NSColor(calibratedRed: 0.05, green: 0.62, blue: 0.85, alpha: 1),
])!
gradient.draw(in: path, angle: -55)

// subtle inner border
path.lineWidth = 14
NSColor.white.withAlphaComponent(0.18).setStroke()
path.stroke()

// "</>" mark
let para = NSMutableParagraphStyle()
para.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 380, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: para,
]
let mark = "</>" as NSString
let markSize = mark.size(withAttributes: attrs)
let markX = (CGFloat(size) - markSize.width) / 2
let markY = (CGFloat(size) - markSize.height) / 2 + 10
mark.draw(at: NSPoint(x: markX, y: markY), withAttributes: attrs)

// small accent bar under the mark
let barRect = NSRect(x: CGFloat(size) / 2 - 130, y: CGFloat(size) / 2 - markSize.height / 2 + 6, width: 260, height: 16)
let bar = NSBezierPath(roundedRect: barRect, xRadius: 8, yRadius: 8)
NSColor.white.withAlphaComponent(0.85).setFill()
bar.fill()

image.unlockFocus()

let iconsetPath = "build/icon.iconset"
try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

for (px, name) in specs {
    let resized = NSImage(size: NSSize(width: px, height: px), flipped: false) { drawRect in
        image.draw(in: drawRect)
        return true
    }
    guard let tiff = resized.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("failed to render \(name)")
        continue
    }
    try png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}
print("iconset written to \(iconsetPath)")
