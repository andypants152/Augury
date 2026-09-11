import AppKit
import Foundation

// Rasterizes the SVG drafts into contact-sheet PNGs so the whole deck can be
// eyeballed at once. Reads <dir>/_order.txt for layout order if present,
// otherwise falls back to a sorted glob.
//
//   swift montage.swift <draftsDir> [s|m|l|all]
//
// Presets (3 sizes, per the M2 done-when "renders at 3 sizes"):
//   s  — overview:   13 cols, 56px thumbs   → _contact-sheet-s.png
//   m  — reading:     9 cols, 150px thumbs  → _contact-sheet-m.png
//   l  — review:      6 cols, 320px thumbs  → _contact-sheet-l.png
//   all (default) — writes all three.
//
// Legacy single-sheet form (one custom sheet, old behavior):
//   swift montage.swift <draftsDir> <cols> <thumbW> [outPath]
//
// Exits non-zero if any draft fails to load or render (a "no error" gate).

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(
        "usage: montage <draftsDir> [s|m|l|all] | <draftsDir> <cols> <thumbW> [outPath]\n".data(using: .utf8)!)
    exit(2)
}
let dir = args[1]

let fm = FileManager.default
var files: [String]
if let order = try? String(contentsOfFile: dir + "/_order.txt", encoding: .utf8) {
    files = order.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
} else {
    let listing = (try? fm.contentsOfDirectory(atPath: dir)) ?? []
    files = listing.filter { $0.hasSuffix(".svg") }.sorted()
}
guard !files.isEmpty else {
    FileHandle.standardError.write("no .svg files found in \(dir)\n".data(using: .utf8)!)
    exit(1)
}

// One contact sheet of the given files. Returns (loadedCount, totalMissing).
func makeSheet(cols: Int, thumbW: Int, outPath: String) -> (loaded: Int, missing: Int) {
    let thumbH = Int((Double(thumbW) * 960.0 / 540.0).rounded())   // 9:16 card
    let gap = 8
    let rows = (files.count + cols - 1) / cols
    let sheetW = cols * thumbW + (cols + 1) * gap
    let sheetH = rows * thumbH + (rows + 1) * gap

    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: sheetW, pixelsHigh: sheetH,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                     bitsPerPixel: 0) else {
        FileHandle.standardError.write("could not allocate bitmap for \(outPath)\n".data(using: .utf8)!)
        return (0, files.count)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor(white: 0.05, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: sheetW, height: sheetH).fill()

    // Flip the context so row 0 lands at the visual top (Cocoa origin is bottom-left).
    if let ctx = NSGraphicsContext.current {
        ctx.cgContext.translateBy(x: 0, y: CGFloat(sheetH))
        ctx.cgContext.scaleBy(x: 1, y: -1)
    }

    var loaded = 0
    var missing = 0
    for (i, f) in files.enumerated() {
        let col = i % cols
        let row = i / cols
        let x = gap + col * (thumbW + gap)
        let y = gap + row * (thumbH + gap)      // top-left, because the context is flipped
        let rect = NSRect(x: x, y: y, width: thumbW, height: thumbH)
        if let img = NSImage(contentsOfFile: dir + "/" + f) {
            img.draw(in: rect)
            loaded += 1
        } else {
            missing += 1
            FileHandle.standardError.write("MISSING  \(f)\n".data(using: .utf8)!)
            NSColor.systemRed.setFill()
            rect.fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("could not encode png for \(outPath)\n".data(using: .utf8)!)
        return (loaded, missing + 1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: outPath))
    } catch {
        FileHandle.standardError.write("could not write \(outPath): \(error)\n".data(using: .utf8)!)
        return (loaded, missing + 1)
    }
    print("\(outPath)  (\(sheetW)x\(sheetH)px, \(loaded)/\(files.count) cards, \(rows) rows x \(cols) cols)")
    return (loaded, missing)
}

// ─────────────────────────── dispatch ───────────────────────────
struct Preset { let name: String; let cols: Int; let thumbW: Int }
let presets: [Preset] = [
    Preset(name: "s", cols: 13, thumbW: 56),
    Preset(name: "m", cols: 9,  thumbW: 150),
    Preset(name: "l", cols: 6,  thumbW: 320),
]

var exitCode = 0
let tail = Array(args.dropFirst(2))

if tail.isEmpty || tail == ["all"] {
    // The 3-size preview (M2 done-when).
    for p in presets {
        let (_, missing) = makeSheet(cols: p.cols, thumbW: p.thumbW,
                                     outPath: dir + "/_contact-sheet-\(p.name).png")
        if missing > 0 { exitCode = 1 }
    }
} else if let p = presets.first(where: { $0.name == tail[0] }), tail.count == 1 {
    let (_, missing) = makeSheet(cols: p.cols, thumbW: p.thumbW,
                                 outPath: dir + "/_contact-sheet-\(p.name).png")
    if missing > 0 { exitCode = 1 }
} else if tail.count >= 2, let cols = Int(tail[0]), let thumbW = Int(tail[1]), cols > 0, thumbW > 0 {
    // Legacy single-sheet form: <dir> <cols> <thumbW> [outPath]
    let outPath = tail.count >= 3 ? tail[2] : dir + "/_contact-sheet.png"
    let (_, missing) = makeSheet(cols: cols, thumbW: thumbW, outPath: outPath)
    if missing > 0 { exitCode = 1 }
} else {
    FileHandle.standardError.write("unknown arguments: \(tail.joined(separator: " "))\n".data(using: .utf8)!)
    exit(2)
}
exit(Int32(exitCode))
