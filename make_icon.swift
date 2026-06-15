#!/usr/bin/swift
// Generates BookShelf.icns — a golden open-book icon similar to Apple Books
// but with distinct golden color and text lines on pages.
// Run: swift make_icon.swift

import AppKit
import Foundation

let BASE: CGFloat = 1024

func makeIcon(size: CGFloat) -> NSBitmapImageRep {
    let s = size / BASE

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    let c = NSGraphicsContext(bitmapImageRep: rep)!.cgContext

    // Flip to top-left origin
    c.translateBy(x: 0, y: size)
    c.scaleBy(x: 1, y: -1)

    // ~10% transparent margin each side, matching Apple's icon template safe zone
    let margin: CGFloat = 100 * s
    c.translateBy(x: margin, y: margin)
    c.scaleBy(x: (size - 2*margin)/size, y: (size - 2*margin)/size)

    let cs = CGColorSpaceCreateDeviceRGB()
    func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(colorSpace: cs, components: [r/255, g/255, b/255, a])!
    }

    // ── Background gradient: warm golden amber ──
    let grad = CGGradient(
        colorsSpace: cs,
        colors: [rgb(248, 178, 24), rgb(192, 104, 6)] as CFArray,
        locations: [0, 1])!

    let corner = 225 * s
    let roundedPath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
        cornerWidth: corner, cornerHeight: corner, transform: nil)

    c.saveGState()
    c.addPath(roundedPath)
    c.clip()
    c.drawLinearGradient(grad,
        start: CGPoint(x: size/2, y: 0), end: CGPoint(x: size/2, y: size), options: [])
    c.restoreGState()

    // ── Book geometry ──
    let cx = size * 0.5
    let cy = size * 0.505
    let pw   = 244 * s   // page half-width
    let spTY = cy - 193 * s  // spine top-y
    let spBY = cy + 218 * s  // spine bottom-y
    let droop = 26 * s       // outer edge drops this much below spine-top
    let gap   = 6 * s        // half-gap at spine

    // Page vertices (top-left origin)
    let lp: [CGPoint] = [
        CGPoint(x: cx - gap, y: spTY),
        CGPoint(x: cx - pw,  y: spTY + droop),
        CGPoint(x: cx - pw,  y: spBY - droop),
        CGPoint(x: cx - gap, y: spBY),
    ]
    let rp: [CGPoint] = [
        CGPoint(x: cx + gap, y: spTY),
        CGPoint(x: cx + pw,  y: spTY + droop),
        CGPoint(x: cx + pw,  y: spBY - droop),
        CGPoint(x: cx + gap, y: spBY),
    ]

    func poly(_ pts: [CGPoint]) {
        c.move(to: pts[0])
        pts.dropFirst().forEach { c.addLine(to: $0) }
        c.closePath()
    }

    // Drop shadow
    c.saveGState()
    c.setShadow(offset: CGSize(width: 6*s, height: 14*s), blur: 22*s,
                color: CGColor(gray: 0, alpha: 0.38))
    c.setFillColor(CGColor(gray: 1, alpha: 1))
    poly(lp); c.fillPath()
    poly(rp); c.fillPath()
    c.restoreGState()

    // Left page
    c.setFillColor(rgb(255, 255, 255))
    poly(lp); c.fillPath()

    // Right page (very slightly off-white)
    c.setFillColor(rgb(252, 251, 248))
    poly(rp); c.fillPath()

    // Page-stack edges (thin strip at spine on each page)
    let peW = 6 * s
    c.setFillColor(rgb(220, 214, 204))
    poly([lp[0], CGPoint(x: lp[0].x - peW, y: lp[0].y + 4*s),
          CGPoint(x: lp[3].x - peW, y: lp[3].y - 4*s), lp[3]])
    c.fillPath()
    poly([rp[0], CGPoint(x: rp[0].x + peW, y: rp[0].y + 4*s),
          CGPoint(x: rp[3].x + peW, y: rp[3].y - 4*s), rp[3]])
    c.fillPath()

    // ── Text lines on pages ──
    c.setFillColor(rgb(200, 196, 190))
    let xMgn  = 30 * s
    let yTop  = spTY + 60 * s
    let yBot  = spBY - 48 * s
    let lh    = max(1.5, 3 * s)
    let nLines = 9

    for i in 0..<nLines {
        let t = CGFloat(i) / CGFloat(nLines - 1)
        let y = yTop + t * (yBot - yTop)
        // Left page line
        c.fill(CGRect(x: lp[1].x + xMgn, y: y - lh/2,
                      width: (lp[0].x - xMgn) - (lp[1].x + xMgn), height: lh))
        // Right page line
        c.fill(CGRect(x: rp[0].x + xMgn, y: y - lh/2,
                      width: (rp[1].x - xMgn) - (rp[0].x + xMgn), height: lh))
    }

    // ── Spine ──
    let spW = 13 * s
    c.setFillColor(rgb(168, 128, 40, 0.85))
    c.fill(CGRect(x: cx - spW/2, y: spTY, width: spW, height: spBY - spTY))

    // ── Bookmark ribbon on top-right of right page ──
    let bmX = rp[1].x - 55 * s
    let bmY = rp[1].y
    let bmW = 27 * s
    let bmH = 80 * s
    c.setFillColor(rgb(205, 68, 42, 0.93))
    poly([
        CGPoint(x: bmX,        y: bmY),
        CGPoint(x: bmX + bmW,  y: bmY),
        CGPoint(x: bmX + bmW,  y: bmY + bmH),
        CGPoint(x: bmX + bmW/2, y: bmY + bmH - 18*s),
        CGPoint(x: bmX,        y: bmY + bmH),
    ])
    c.fillPath()

    return rep
}

// ── Generate iconset ──
let fm = FileManager.default
let iconsetDir = "icon_gen/BookShelf.iconset"
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(Int, String, Int)] = [
    (16,"16x16",1),(16,"16x16",2),
    (32,"32x32",1),(32,"32x32",2),
    (128,"128x128",1),(128,"128x128",2),
    (256,"256x256",1),(256,"256x256",2),
    (512,"512x512",1),(512,"512x512",2),
]

for (base, name, scale) in sizes {
    let sz = CGFloat(base * scale)
    let rep = makeIcon(size: sz)
    let suffix = scale == 1 ? "" : "@2x"
    let path = "\(iconsetDir)/icon_\(name)\(suffix).png"
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("  \(path)")
}

// ── iconutil → .icns ──
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", "icon_gen/BookShelf.icns"]
try! proc.run()
proc.waitUntilExit()

guard proc.terminationStatus == 0 else {
    print("iconutil failed"); exit(1)
}
print("Created icon_gen/BookShelf.icns")

// ── Install into .app bundle ──
let dest = "BookShelf.app/Contents/Resources/BookShelf.icns"
try? fm.removeItem(atPath: dest)
try! fm.copyItem(atPath: "icon_gen/BookShelf.icns", toPath: dest)
print("Installed → \(dest)")
