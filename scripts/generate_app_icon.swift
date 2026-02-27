import AppKit
import Foundation

struct IconSpec {
    let points: Int
    let scale: Int
    var pixels: Int { points * scale }
    var filename: String { "icon_\(points)x\(points)@\(scale)x.png" }
    var sizeString: String { "\(points)x\(points)" }
    var scaleString: String { "\(scale)x" }
}

let specs: [IconSpec] = [
    .init(points: 16, scale: 1),
    .init(points: 16, scale: 2),
    .init(points: 32, scale: 1),
    .init(points: 32, scale: 2),
    .init(points: 128, scale: 1),
    .init(points: 128, scale: 2),
    .init(points: 256, scale: 1),
    .init(points: 256, scale: 2),
    .init(points: 512, scale: 1),
    .init(points: 512, scale: 2)
]

let fileManager = FileManager.default
let assetsDir = URL(fileURLWithPath: "App/Resources/Assets.xcassets", isDirectory: true)
let appIconDir = assetsDir.appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try fileManager.createDirectory(at: assetsDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: appIconDir, withIntermediateDirectories: true)

func drawIcon(size px: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()

    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    NSColor(calibratedRed: 0.95, green: 0.97, blue: 1.0, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(px) * 0.02, dy: CGFloat(px) * 0.02), xRadius: CGFloat(px) * 0.2, yRadius: CGFloat(px) * 0.2).fill()

    let pageRect = NSRect(
        x: CGFloat(px) * 0.16,
        y: CGFloat(px) * 0.14,
        width: CGFloat(px) * 0.68,
        height: CGFloat(px) * 0.74
    )
    NSColor.white.setFill()
    NSBezierPath(roundedRect: pageRect, xRadius: CGFloat(px) * 0.06, yRadius: CGFloat(px) * 0.06).fill()

    let headerRect = NSRect(
        x: pageRect.minX,
        y: pageRect.maxY - CGFloat(px) * 0.2,
        width: pageRect.width,
        height: CGFloat(px) * 0.2
    )
    NSColor(calibratedRed: 0.28, green: 0.45, blue: 0.74, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: headerRect, xRadius: CGFloat(px) * 0.05, yRadius: CGFloat(px) * 0.05).fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: CGFloat(px) * 0.11, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    NSString(string: "#").draw(at: NSPoint(x: headerRect.minX + CGFloat(px) * 0.04, y: headerRect.minY + CGFloat(px) * 0.03), withAttributes: titleAttributes)

    let lineColor = NSColor(calibratedRed: 0.33, green: 0.39, blue: 0.5, alpha: 0.35)
    for i in 0..<5 {
        let y = pageRect.maxY - CGFloat(px) * 0.26 - CGFloat(i) * CGFloat(px) * 0.09
        let line = NSBezierPath()
        line.move(to: NSPoint(x: pageRect.minX + CGFloat(px) * 0.05, y: y))
        line.line(to: NSPoint(x: pageRect.maxX - CGFloat(px) * 0.05, y: y))
        line.lineWidth = CGFloat(px) * 0.012
        lineColor.setStroke()
        line.stroke()
    }

    let eyeCenter = NSPoint(x: pageRect.maxX - CGFloat(px) * 0.14, y: pageRect.minY + CGFloat(px) * 0.16)
    let eyeOuter = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - CGFloat(px) * 0.16, y: eyeCenter.y - CGFloat(px) * 0.09, width: CGFloat(px) * 0.32, height: CGFloat(px) * 0.18))
    NSColor(calibratedRed: 0.15, green: 0.33, blue: 0.61, alpha: 0.95).setStroke()
    eyeOuter.lineWidth = CGFloat(px) * 0.018
    eyeOuter.stroke()

    let pupil = NSBezierPath(ovalIn: NSRect(x: eyeCenter.x - CGFloat(px) * 0.05, y: eyeCenter.y - CGFloat(px) * 0.05, width: CGFloat(px) * 0.1, height: CGFloat(px) * 0.1))
    NSColor(calibratedRed: 0.15, green: 0.33, blue: 0.61, alpha: 0.95).setFill()
    pupil.fill()

    return image
}

func writePNG(image: NSImage, to url: URL, pixels: Int) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon-gen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert icon image to PNG"])
    }

    try pngData.write(to: url)
}

for spec in specs {
    let image = drawIcon(size: spec.pixels)
    let iconURL = appIconDir.appendingPathComponent(spec.filename)
    try writePNG(image: image, to: iconURL, pixels: spec.pixels)
}

let appIconContents: [String: Any] = [
    "images": specs.map { spec in
        [
            "idiom": "mac",
            "size": spec.sizeString,
            "scale": spec.scaleString,
            "filename": spec.filename
        ]
    },
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

let assetsContents: [String: Any] = [
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

let appIconContentsData = try JSONSerialization.data(withJSONObject: appIconContents, options: [.prettyPrinted, .sortedKeys])
let assetsContentsData = try JSONSerialization.data(withJSONObject: assetsContents, options: [.prettyPrinted, .sortedKeys])

try appIconContentsData.write(to: appIconDir.appendingPathComponent("Contents.json"))
try assetsContentsData.write(to: assetsDir.appendingPathComponent("Contents.json"))

print("Generated icons in \(appIconDir.path)")
