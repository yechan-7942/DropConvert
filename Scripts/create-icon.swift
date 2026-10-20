import AppKit
import Foundation

let size = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocusFlipped(false)

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 18, dy: 18), xRadius: 224, yRadius: 224)
NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.13, alpha: 1).setFill()
background.fill()

let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.34, alpha: 0.75),
    NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.13, alpha: 0)
])!
glow.draw(in: NSRect(x: 96, y: 504, width: 832, height: 440), angle: 90)

func arrowPath(center: NSPoint, radius: CGFloat, angle: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    let points: [NSPoint] = [
        NSPoint(x: 0, y: 110), NSPoint(x: 190, y: 110), NSPoint(x: 190, y: 190),
        NSPoint(x: 340, y: 0), NSPoint(x: 190, y: -190), NSPoint(x: 190, y: -110),
        NSPoint(x: 0, y: -110)
    ]
    for (index, point) in points.enumerated() {
        let x = point.x * cos(angle) - point.y * sin(angle) + center.x
        let y = point.x * sin(angle) + point.y * cos(angle) + center.y
        if index == 0 { path.move(to: NSPoint(x: x, y: y)) }
        else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    return path
}

let cyan = NSColor(calibratedRed: 0.12, green: 0.80, blue: 0.92, alpha: 1)
let amber = NSColor(calibratedRed: 1.0, green: 0.60, blue: 0.24, alpha: 1)
let first = arrowPath(center: NSPoint(x: 512, y: 570), radius: 340, angle: 0)
let second = arrowPath(center: NSPoint(x: 512, y: 454), radius: 340, angle: .pi)
cyan.setFill()
first.fill()
amber.setFill()
second.fill()

NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 422, y: 422, width: 180, height: 180))
ring.lineWidth = 8
ring.stroke()

image.unlockFocus()
guard let data = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: data),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not create PNG icon")
}
try png.write(to: output)
