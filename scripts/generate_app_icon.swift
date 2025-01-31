import AppKit
import Foundation

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

// Fill background with white
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()

// Draw emoji
let emoji = "🍑"
let font = NSFont.systemFont(ofSize: 750)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black
]

let textSize = emoji.size(withAttributes: attributes)
let point = CGPoint(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2
)
emoji.draw(at: point, withAttributes: attributes)

image.unlockFocus()

// Save as PNG
if let tiffData = image.tiffRepresentation,
   let bitmapImage = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
    try pngData.write(to: URL(fileURLWithPath: "/tmp/peach_icon/base.png"))
}
