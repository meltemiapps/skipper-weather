import SwiftUI

/// Original, text-free lesson diagrams drawn natively so they need no translation.
struct DiagramView: View {
    let id: String

    var body: some View {
        Canvas { ctx, size in
            switch id {
            case "buysBallot": Self.buysBallot(&ctx, size)
            case "warmFront": Self.warmFront(&ctx, size)
            case "seaBreeze": Self.seaBreeze(&ctx, size)
            case "fog": Self.fog(&ctx, size)
            default: break
            }
        }
        .environment(\.layoutDirection, .leftToRight) // meteorological diagrams are never mirrored
    }

    private static let line = Color.white.opacity(0.75)
    private static let wind = Palette.accent

    private static func arrow(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint, color: Color, width: CGFloat = 2.5) {
        var p = Path()
        p.move(to: a); p.addLine(to: b)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let head: CGFloat = 9
        p.move(to: b)
        p.addLine(to: CGPoint(x: b.x - head * cos(angle - .pi / 7), y: b.y - head * sin(angle - .pi / 7)))
        p.move(to: b)
        p.addLine(to: CGPoint(x: b.x - head * cos(angle + .pi / 7), y: b.y - head * sin(angle + .pi / 7)))
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private static func label(_ ctx: inout GraphicsContext, _ text: String, at p: CGPoint, color: Color, size: CGFloat = 26) {
        ctx.draw(Text(verbatim: text).font(.system(size: size, weight: .heavy)).foregroundStyle(color), at: p)
    }

    /// Isobars around a low with surface wind spiralling anticlockwise and inwards (N. Hemisphere).
    static func buysBallot(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        for i in 1...4 {
            let rx = CGFloat(i) * size.width * 0.11, ry = CGFloat(i) * size.height * 0.1
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)),
                       with: .color(line), lineWidth: 1.5)
        }
        label(&ctx, "L", at: c, color: Palette.amber)
        let rx = size.width * 0.33, ry = size.height * 0.3
        for k in 0..<8 {
            let theta = Double(k) * .pi / 4
            let p = CGPoint(x: c.x + rx * cos(theta), y: c.y + ry * sin(theta))
            // Tangent for anticlockwise flow on screen (y down) is (sin, -cos); add 15° inflow.
            let tangent = CGVector(dx: sin(theta), dy: -cos(theta))
            let inward = CGVector(dx: -cos(theta), dy: -sin(theta))
            let inflow = 0.27
            let d = CGVector(dx: tangent.dx + inward.dx * inflow, dy: tangent.dy + inward.dy * inflow)
            arrow(&ctx, from: CGPoint(x: p.x - d.dx * 16, y: p.y - d.dy * 16),
                  to: CGPoint(x: p.x + d.dx * 16, y: p.y + d.dy * 16), color: wind)
        }
    }

    /// Cross-section of a warm front: shallow frontal slope, lowering cloud, rain ahead of the surface front.
    static func warmFront(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height, ground = h * 0.85
        var groundPath = Path(); groundPath.move(to: CGPoint(x: 0, y: ground)); groundPath.addLine(to: CGPoint(x: w, y: ground))
        ctx.stroke(groundPath, with: .color(line), lineWidth: 2)
        let frontX = w * 0.3
        var front = Path(); front.move(to: CGPoint(x: frontX, y: ground)); front.addLine(to: CGPoint(x: w * 0.95, y: h * 0.12))
        ctx.stroke(front, with: .color(Palette.bad), lineWidth: 3)
        // Warm air rising over the wedge of cold air.
        arrow(&ctx, from: CGPoint(x: w * 0.08, y: ground - 14), to: CGPoint(x: frontX + 10, y: ground - 24), color: Palette.amber)
        arrow(&ctx, from: CGPoint(x: frontX + 20, y: ground - 40), to: CGPoint(x: w * 0.7, y: h * 0.38), color: Palette.amber)
        // Cloud layer thickening and lowering towards the surface front.
        var cloud = Path()
        cloud.move(to: CGPoint(x: w * 0.95, y: h * 0.1))
        cloud.addLine(to: CGPoint(x: frontX + 4, y: ground - 30))
        cloud.addLine(to: CGPoint(x: frontX + 60, y: ground - 30))
        cloud.addLine(to: CGPoint(x: w * 0.97, y: h * 0.2))
        cloud.closeSubpath()
        ctx.fill(cloud, with: .color(.white.opacity(0.22)))
        // Rain band ahead of the surface front.
        for i in 0..<9 {
            let x = frontX + 8 + CGFloat(i) * 12
            var drop = Path(); drop.move(to: CGPoint(x: x, y: ground - 24)); drop.addLine(to: CGPoint(x: x - 4, y: ground - 6))
            ctx.stroke(drop, with: .color(wind), lineWidth: 1.5)
        }
        label(&ctx, "↙", at: CGPoint(x: w * 0.85, y: ground - 20), color: line, size: 18)
    }

    /// Daytime circulation: air rises over warm land, flows out aloft, sinks over sea, returns onshore.
    static func seaBreeze(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height, surface = h * 0.75
        ctx.fill(Path(CGRect(x: 0, y: surface, width: w * 0.5, height: h - surface)), with: .color(Color(red: 0.1, green: 0.45, blue: 0.8).opacity(0.6)))
        ctx.fill(Path(CGRect(x: w * 0.5, y: surface - 6, width: w * 0.5, height: h - surface + 6)), with: .color(Color(red: 0.55, green: 0.45, blue: 0.25).opacity(0.8)))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.8, y: h * 0.05, width: 34, height: 34)), with: .color(Palette.amber))
        arrow(&ctx, from: CGPoint(x: w * 0.2, y: surface - 16), to: CGPoint(x: w * 0.62, y: surface - 16), color: wind)
        arrow(&ctx, from: CGPoint(x: w * 0.7, y: surface - 24), to: CGPoint(x: w * 0.7, y: h * 0.25), color: Palette.amber)
        arrow(&ctx, from: CGPoint(x: w * 0.65, y: h * 0.18), to: CGPoint(x: w * 0.25, y: h * 0.18), color: line)
        arrow(&ctx, from: CGPoint(x: w * 0.15, y: h * 0.25), to: CGPoint(x: w * 0.15, y: surface - 28), color: line)
        // Cumulus over the land.
        for (dx, r) in [(0.0, 16.0), (18.0, 20.0), (38.0, 15.0)] {
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.62 + dx, y: h * 0.12 - r / 2, width: r * 2, height: r * 1.6)), with: .color(.white.opacity(0.8)))
        }
    }

    /// Advection fog: warm moist air moving over a cold sea, forming a fog layer at the surface.
    static func fog(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height, surface = h * 0.78
        ctx.fill(Path(CGRect(x: 0, y: surface, width: w, height: h - surface)), with: .color(Color(red: 0.1, green: 0.35, blue: 0.7).opacity(0.7)))
        for i in 0..<4 {
            let y = surface - 8 - CGFloat(i) * 10
            let alpha = 0.45 - Double(i) * 0.1
            ctx.fill(Path(roundedRect: CGRect(x: w * 0.35, y: y - 6, width: w * 0.62, height: 12), cornerRadius: 6), with: .color(.white.opacity(alpha)))
        }
        arrow(&ctx, from: CGPoint(x: w * 0.04, y: h * 0.35), to: CGPoint(x: w * 0.4, y: h * 0.5), color: Palette.amber, width: 3)
        label(&ctx, "❄︎", at: CGPoint(x: w * 0.7, y: surface + (h - surface) / 2), color: .white, size: 18)
    }
}
