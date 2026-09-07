import AppKit

func drawIcon(_ px: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil, pixelsWide:Int(px), pixelsHigh:Int(px), bitsPerSample:8, samplesPerPixel:4, hasAlpha:true, isPlanar:false, colorSpaceName:.deviceRGB, bytesPerRow:0, bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let S = px

    // Fond : squircle dégradé graphite, avec une marge façon icône macOS
    let pad = S*0.06
    let rect = NSRect(x:pad, y:pad, width:S-2*pad, height:S-2*pad)
    let r = rect.width*0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius:r, yRadius:r)
    let grad = NSGradient(colors:[
        NSColor(srgbRed:0.20, green:0.22, blue:0.32, alpha:1),
        NSColor(srgbRed:0.09, green:0.10, blue:0.16, alpha:1)])!
    grad.draw(in: path, angle: -90)
    // fin liseré interne
    NSColor(white:1, alpha:0.06).setStroke()
    let inner = NSBezierPath(roundedRect: rect.insetBy(dx: S*0.006, dy: S*0.006), xRadius:r, yRadius:r)
    inner.lineWidth = S*0.006; inner.stroke()

    // Deux barres de conso
    let barW = S*0.60, barH = S*0.135, x = (S-barW)/2
    let gap = S*0.085
    let total = barH*2 + gap
    let bottomY = (S-total)/2
    let topY = bottomY + barH + gap
    let rad = barH/2

    func bar(_ y: CGFloat, _ frac: CGFloat, _ col: NSColor) {
        let track = NSBezierPath(roundedRect: NSRect(x:x,y:y,width:barW,height:barH), xRadius:rad, yRadius:rad)
        NSColor(white:1, alpha:0.16).setFill(); track.fill()
        let fw = max(barH, barW*frac)
        let fill = NSBezierPath(roundedRect: NSRect(x:x,y:y,width:fw,height:barH), xRadius:rad, yRadius:rad)
        col.setFill(); fill.fill()
    }
    bar(topY, 0.52, NSColor(srgbRed:0.30, green:0.82, blue:0.45, alpha:1))   // vert
    bar(bottomY, 0.74, NSColor(srgbRed:0.98, green:0.62, blue:0.18, alpha:1)) // orange

    // Curseur de rythme : trait vertical blanc traversant les deux barres
    let markerX = x + barW*0.62
    let mW = S*0.028
    let mY = bottomY - S*0.03
    let mH = (topY + barH) - mY + S*0.03
    ctx.setShadow(offset: .zero, blur: S*0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    let marker = NSBezierPath(roundedRect: NSRect(x:markerX - mW/2, y:mY, width:mW, height:mH), xRadius:mW/2, yRadius:mW/2)
    NSColor.white.setFill(); marker.fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    try? rep.representation(using:.png, properties:[:])!.write(to: URL(fileURLWithPath:path))
}

let outDir = CommandLine.arguments[1]
let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes { save(drawIcon(px), "\(outDir)/\(name).png") }
save(drawIcon(512), "\(outDir)/../preview-512.png")
save(drawIcon(64), "\(outDir)/../preview-64.png")
print("icons written")
