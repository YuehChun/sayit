#!/usr/bin/env swift

import AppKit
import Foundation

func drawCatIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus(); return image
    }

    let s = size

    // === Background: orange rounded rectangle ===
    let bgRect = CGRect(x: s * 0.02, y: s * 0.02, width: s * 0.96, height: s * 0.96)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: s * 0.22, cornerHeight: s * 0.22, transform: nil)
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 1),
        CGColor(red: 0.96, green: 0.42, blue: 0.16, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.drawLinearGradient(grad, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    ctx.restoreGState()

    // === Cat body (white chest/neck area) ===
    ctx.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1))
    let bodyPath = CGMutablePath()
    bodyPath.move(to: CGPoint(x: s * 0.30, y: s * 0.05))
    bodyPath.addQuadCurve(to: CGPoint(x: s * 0.70, y: s * 0.05),
                          control: CGPoint(x: s * 0.50, y: s * 0.10))
    bodyPath.addLine(to: CGPoint(x: s * 0.72, y: s * 0.28))
    bodyPath.addQuadCurve(to: CGPoint(x: s * 0.28, y: s * 0.28),
                          control: CGPoint(x: s * 0.50, y: s * 0.22))
    bodyPath.closeSubpath()
    ctx.addPath(bodyPath)
    ctx.fillPath()

    // Gray chest shadow
    ctx.setFillColor(CGColor(red: 0.85, green: 0.85, blue: 0.86, alpha: 0.6))
    let chestShadow = CGMutablePath()
    chestShadow.move(to: CGPoint(x: s * 0.35, y: s * 0.05))
    chestShadow.addQuadCurve(to: CGPoint(x: s * 0.65, y: s * 0.05),
                              control: CGPoint(x: s * 0.50, y: s * 0.09))
    chestShadow.addLine(to: CGPoint(x: s * 0.62, y: s * 0.15))
    chestShadow.addQuadCurve(to: CGPoint(x: s * 0.38, y: s * 0.15),
                              control: CGPoint(x: s * 0.50, y: s * 0.12))
    chestShadow.closeSubpath()
    ctx.addPath(chestShadow)
    ctx.fillPath()

    // === Head (white base) ===
    let headCX = s * 0.50
    let headCY = s * 0.42
    let headRX = s * 0.30
    let headRY = s * 0.25

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: headCX - headRX, y: headCY - headRY,
                                width: headRX * 2, height: headRY * 2))

    // === Ears (black outer) ===
    let blackColor = CGColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
    ctx.setFillColor(blackColor)

    // Left ear
    let earL = CGMutablePath()
    earL.move(to: CGPoint(x: s * 0.18, y: s * 0.55))
    earL.addLine(to: CGPoint(x: s * 0.14, y: s * 0.82))
    earL.addLine(to: CGPoint(x: s * 0.40, y: s * 0.64))
    earL.closeSubpath()
    ctx.addPath(earL); ctx.fillPath()

    // Right ear
    let earR = CGMutablePath()
    earR.move(to: CGPoint(x: s * 0.82, y: s * 0.55))
    earR.addLine(to: CGPoint(x: s * 0.86, y: s * 0.82))
    earR.addLine(to: CGPoint(x: s * 0.60, y: s * 0.64))
    earR.closeSubpath()
    ctx.addPath(earR); ctx.fillPath()

    // Inner ears (pink)
    ctx.setFillColor(CGColor(red: 0.78, green: 0.55, blue: 0.56, alpha: 1))
    let inL = CGMutablePath()
    inL.move(to: CGPoint(x: s * 0.21, y: s * 0.58))
    inL.addLine(to: CGPoint(x: s * 0.19, y: s * 0.76))
    inL.addLine(to: CGPoint(x: s * 0.37, y: s * 0.63))
    inL.closeSubpath()
    ctx.addPath(inL); ctx.fillPath()

    let inR = CGMutablePath()
    inR.move(to: CGPoint(x: s * 0.79, y: s * 0.58))
    inR.addLine(to: CGPoint(x: s * 0.81, y: s * 0.76))
    inR.addLine(to: CGPoint(x: s * 0.63, y: s * 0.63))
    inR.closeSubpath()
    ctx.addPath(inR); ctx.fillPath()

    // === Black cap (forehead + sides, leaving white inverted-Y) ===
    ctx.setFillColor(blackColor)

    // Left side of cap
    let cL = CGMutablePath()
    cL.move(to: CGPoint(x: s * 0.20, y: s * 0.40))
    cL.addQuadCurve(to: CGPoint(x: s * 0.25, y: s * 0.65),
                     control: CGPoint(x: s * 0.18, y: s * 0.55))
    cL.addQuadCurve(to: CGPoint(x: s * 0.43, y: s * 0.67),
                     control: CGPoint(x: s * 0.33, y: s * 0.69))
    // White stripe border
    cL.addLine(to: CGPoint(x: s * 0.43, y: s * 0.58))
    cL.addQuadCurve(to: CGPoint(x: s * 0.45, y: s * 0.44),
                     control: CGPoint(x: s * 0.43, y: s * 0.52))
    cL.addLine(to: CGPoint(x: s * 0.32, y: s * 0.40))
    cL.addQuadCurve(to: CGPoint(x: s * 0.20, y: s * 0.40),
                     control: CGPoint(x: s * 0.24, y: s * 0.38))
    cL.closeSubpath()
    ctx.addPath(cL); ctx.fillPath()

    // Right side of cap
    let cR = CGMutablePath()
    cR.move(to: CGPoint(x: s * 0.80, y: s * 0.40))
    cR.addQuadCurve(to: CGPoint(x: s * 0.75, y: s * 0.65),
                     control: CGPoint(x: s * 0.82, y: s * 0.55))
    cR.addQuadCurve(to: CGPoint(x: s * 0.57, y: s * 0.67),
                     control: CGPoint(x: s * 0.67, y: s * 0.69))
    cR.addLine(to: CGPoint(x: s * 0.57, y: s * 0.58))
    cR.addQuadCurve(to: CGPoint(x: s * 0.55, y: s * 0.44),
                     control: CGPoint(x: s * 0.57, y: s * 0.52))
    cR.addLine(to: CGPoint(x: s * 0.68, y: s * 0.40))
    cR.addQuadCurve(to: CGPoint(x: s * 0.80, y: s * 0.40),
                     control: CGPoint(x: s * 0.76, y: s * 0.38))
    cR.closeSubpath()
    ctx.addPath(cR); ctx.fillPath()

    // === Eyes (large, blue) ===
    let eyeY = s * 0.44
    let lx = s * 0.36, rx = s * 0.64
    let eyeR = s * 0.065

    // White sclera
    ctx.setFillColor(CGColor(red: 0.92, green: 0.95, blue: 0.88, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: lx - eyeR, y: eyeY - eyeR, width: eyeR*2, height: eyeR*2))
    ctx.fillEllipse(in: CGRect(x: rx - eyeR, y: eyeY - eyeR, width: eyeR*2, height: eyeR*2))

    // Blue iris
    let irisR = s * 0.052
    ctx.setFillColor(CGColor(red: 0.15, green: 0.55, blue: 0.75, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: lx - irisR, y: eyeY - irisR, width: irisR*2, height: irisR*2))
    ctx.fillEllipse(in: CGRect(x: rx - irisR, y: eyeY - irisR, width: irisR*2, height: irisR*2))

    // Darker blue ring
    let ringR = s * 0.054
    ctx.setStrokeColor(CGColor(red: 0.08, green: 0.30, blue: 0.50, alpha: 0.6))
    ctx.setLineWidth(s * 0.006)
    ctx.strokeEllipse(in: CGRect(x: lx - ringR, y: eyeY - ringR, width: ringR*2, height: ringR*2))
    ctx.strokeEllipse(in: CGRect(x: rx - ringR, y: eyeY - ringR, width: ringR*2, height: ringR*2))

    // Pupils
    ctx.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.12, alpha: 1))
    let pW = s * 0.024, pH = s * 0.065
    ctx.fillEllipse(in: CGRect(x: lx - pW/2, y: eyeY - pH/2, width: pW, height: pH))
    ctx.fillEllipse(in: CGRect(x: rx - pW/2, y: eyeY - pH/2, width: pW, height: pH))

    // Big white highlights
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    let hlR = s * 0.02
    ctx.fillEllipse(in: CGRect(x: lx + s*0.015 - hlR, y: eyeY + s*0.02 - hlR, width: hlR*2, height: hlR*2))
    ctx.fillEllipse(in: CGRect(x: rx + s*0.015 - hlR, y: eyeY + s*0.02 - hlR, width: hlR*2, height: hlR*2))
    // Small highlight
    let hl2 = s * 0.008
    ctx.fillEllipse(in: CGRect(x: lx - s*0.02 - hl2, y: eyeY - s*0.015 - hl2, width: hl2*2, height: hl2*2))
    ctx.fillEllipse(in: CGRect(x: rx - s*0.02 - hl2, y: eyeY - s*0.015 - hl2, width: hl2*2, height: hl2*2))

    // === Pink nose ===
    ctx.setFillColor(CGColor(red: 0.88, green: 0.55, blue: 0.58, alpha: 1))
    let np = CGMutablePath()
    let nY = s * 0.355
    np.move(to: CGPoint(x: s * 0.50, y: nY + s * 0.02))
    np.addQuadCurve(to: CGPoint(x: s * 0.47, y: nY - s * 0.01),
                     control: CGPoint(x: s * 0.465, y: nY + s * 0.015))
    np.addQuadCurve(to: CGPoint(x: s * 0.53, y: nY - s * 0.01),
                     control: CGPoint(x: s * 0.50, y: nY - s * 0.025))
    np.addQuadCurve(to: CGPoint(x: s * 0.50, y: nY + s * 0.02),
                     control: CGPoint(x: s * 0.535, y: nY + s * 0.015))
    np.closeSubpath()
    ctx.addPath(np); ctx.fillPath()

    // === Mouth (open, showing tongue) ===
    // Mouth line down from nose
    ctx.setStrokeColor(CGColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 0.5))
    ctx.setLineWidth(s * 0.006)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: s * 0.50, y: nY - s * 0.01))
    ctx.addLine(to: CGPoint(x: s * 0.50, y: s * 0.30))
    ctx.strokePath()

    // Curved mouth lines
    let mp1 = CGMutablePath()
    mp1.move(to: CGPoint(x: s * 0.50, y: s * 0.30))
    mp1.addQuadCurve(to: CGPoint(x: s * 0.42, y: s * 0.30), control: CGPoint(x: s * 0.46, y: s * 0.285))
    ctx.addPath(mp1); ctx.strokePath()
    let mp2 = CGMutablePath()
    mp2.move(to: CGPoint(x: s * 0.50, y: s * 0.30))
    mp2.addQuadCurve(to: CGPoint(x: s * 0.58, y: s * 0.30), control: CGPoint(x: s * 0.54, y: s * 0.285))
    ctx.addPath(mp2); ctx.strokePath()

    // Open mouth / tongue area
    ctx.setFillColor(CGColor(red: 0.75, green: 0.30, blue: 0.32, alpha: 0.9))
    let tongue = CGMutablePath()
    tongue.move(to: CGPoint(x: s * 0.46, y: s * 0.30))
    tongue.addQuadCurve(to: CGPoint(x: s * 0.54, y: s * 0.30),
                         control: CGPoint(x: s * 0.50, y: s * 0.26))
    tongue.closeSubpath()
    ctx.addPath(tongue); ctx.fillPath()

    // === Whiskers ===
    ctx.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.7))
    ctx.setLineWidth(s * 0.004)

    // Left
    for (sy, ey) in [(0.38, 0.42), (0.36, 0.36), (0.34, 0.30)] {
        ctx.move(to: CGPoint(x: s * 0.34, y: s * sy))
        ctx.addLine(to: CGPoint(x: s * 0.10, y: s * ey))
        ctx.strokePath()
    }
    // Right
    for (sy, ey) in [(0.38, 0.42), (0.36, 0.36), (0.34, 0.30)] {
        ctx.move(to: CGPoint(x: s * 0.66, y: s * sy))
        ctx.addLine(to: CGPoint(x: s * 0.90, y: s * ey))
        ctx.strokePath()
    }

    // === Ear fur tufts (white lines on black) ===
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
    ctx.setLineWidth(s * 0.004)

    // Left ear tufts
    ctx.move(to: CGPoint(x: s * 0.28, y: s * 0.56))
    ctx.addLine(to: CGPoint(x: s * 0.22, y: s * 0.68))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s * 0.30, y: s * 0.57))
    ctx.addLine(to: CGPoint(x: s * 0.25, y: s * 0.66))
    ctx.strokePath()

    // Right ear tufts
    ctx.move(to: CGPoint(x: s * 0.72, y: s * 0.56))
    ctx.addLine(to: CGPoint(x: s * 0.78, y: s * 0.68))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s * 0.70, y: s * 0.57))
    ctx.addLine(to: CGPoint(x: s * 0.75, y: s * 0.66))
    ctx.strokePath()

    // === Forehead fur lines (white on black cap) ===
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.setLineWidth(s * 0.003)

    // Left side
    ctx.move(to: CGPoint(x: s * 0.40, y: s * 0.52))
    ctx.addLine(to: CGPoint(x: s * 0.35, y: s * 0.60))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s * 0.38, y: s * 0.53))
    ctx.addLine(to: CGPoint(x: s * 0.33, y: s * 0.58))
    ctx.strokePath()

    // Right side
    ctx.move(to: CGPoint(x: s * 0.60, y: s * 0.52))
    ctx.addLine(to: CGPoint(x: s * 0.65, y: s * 0.60))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: s * 0.62, y: s * 0.53))
    ctx.addLine(to: CGPoint(x: s * 0.67, y: s * 0.58))
    ctx.strokePath()

    // === Audio waves (bottom right) ===
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.75))
    ctx.setLineWidth(s * 0.012)
    ctx.setLineCap(.round)

    let wX = s * 0.78, wY = s * 0.14
    for i in 0..<3 {
        let r = s * (0.03 + Double(i) * 0.028)
        ctx.addArc(center: CGPoint(x: wX, y: wY), radius: r,
                   startAngle: -.pi/4, endAngle: .pi/4, clockwise: false)
        ctx.strokePath()
    }

    image.unlockFocus()
    return image
}

func savePNG(_ img: NSImage, size: Int, to url: URL) {
    let r = NSImage(size: NSSize(width: size, height: size))
    r.lockFocus()
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    r.unlockFocus()
    guard let t = r.tiffRepresentation, let b = NSBitmapImageRep(data: t),
          let p = b.representation(using: .png, properties: [:]) else { return }
    try! p.write(to: url)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = "\(out)/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let icon = drawCatIcon(size: 1024)
for (n, sz) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
                ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),
                ("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    savePNG(icon, size: sz, to: URL(fileURLWithPath: "\(iconset)/\(n).png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", "\(out)/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)
print(p.terminationStatus == 0 ? "Done" : "Failed")
