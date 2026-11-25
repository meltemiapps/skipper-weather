import SwiftUI
import SkipperCore

/// Native, resolution-independent diagrams. All text comes from the content file's
/// `diagramLabels`, so labels appear in the learner's language.
struct DiagramView: View {
    @Environment(AppModel.self) private var model
    let ref: DiagramRef
    var height: CGFloat = 240

    var body: some View {
        let labels = model.content
        Canvas { ctx, size in
            let p = Painter(ctx: ctx, size: size, name: labels.label)
            switch ref.id {
            case "depression": Diagrams.depression(p, ref.variant ?? "mature")
            case "pressureFeatures": Diagrams.pressureFeatures(p)
            case "frontSection": Diagrams.frontSection(p, ref.variant ?? "warm")
            case "windAngle": Diagrams.windAngle(p, ref.variant ?? "surface")
            case "buysBallot": Diagrams.buysBallot(p)
            case "globalCirculation": Diagrams.globalCirculation(p)
            case "thermal": Diagrams.thermal(p, ref.variant ?? "seaBreeze")
            case "venturi": Diagrams.venturi(p)
            case "coastalConvergence": Diagrams.coastalConvergence(p)
            case "medWinds": Diagrams.medWinds(p)
            case "fog": Diagrams.fog(p, ref.variant ?? "advection")
            case "dewPoint": Diagrams.dewPoint(p)
            case "waves": Diagrams.waves(p, ref.variant ?? "fetch")
            case "seaState": Diagrams.seaState(p, Int(ref.variant ?? "4") ?? 4)
            case "barograph": Diagrams.barograph(p, ref.variant ?? "front")
            case "stability": Diagrams.stability(p, ref.variant ?? "")
            case "cumulonimbus": Diagrams.cumulonimbus(p)
            case "windBarbs": Diagrams.windBarbs(p)
            case "synopticSymbols": Diagrams.synopticSymbols(p)
            case "airColumn": Diagrams.airColumn(p)
            case "airMasses": Diagrams.airMasses(p)
            case "cloudLevels": Diagrams.cloudLevels(p)
            case "visibilityScale": Diagrams.visibilityScale(p)
            case "gribGrid": Diagrams.gribGrid(p)
            case "forecastTimeline": Diagrams.forecastTimeline(p)
            case "passagePlan": Diagrams.passagePlan(p, refuge: ref.variant == "refuge")
            case "heavyWeather": Diagrams.heavyWeather(p)
            default: break
            }
        }
        .frame(height: height)
        .environment(\.layoutDirection, .leftToRight) // charts are never mirrored
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: accessibilitySummary(labels)))
        .accessibilityIdentifier("diagram.\(ref.id)" + (ref.variant.map { ".\($0)" } ?? ""))
    }

    private func accessibilitySummary(_ c: StudyContent) -> String {
        switch ref.id {
        case "depression": return [c.label(.low), c.label(.warmFront), c.label(.warmSector), c.label(.coldFront)].joined(separator: ", ")
        case "frontSection": return c.label(ref.variant == "cold" ? .coldFront : ref.variant == "occluded" ? .occludedFront : .warmFront)
        case "thermal": return c.label(ref.variant == "landBreeze" ? .landBreeze : ref.variant == "katabatic" ? .katabatic : ref.variant == "anabatic" ? .anabatic : .seaBreeze)
        case "fog": return c.label(ref.variant == "radiation" ? .radiationFog : ref.variant == "frontal" ? .frontalFog : .advectionFog)
        default: return c.label(.isobars)
        }
    }
}

// MARK: - Painter

/// Thin drawing helper over GraphicsContext using unit coordinates (0…1).
struct Painter {
    let ctx: GraphicsContext
    let size: CGSize
    let name: (DiagramLabel) -> String

    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * size.width, y: y * size.height) }
    var u: CGFloat { min(size.width, size.height) }

    func stroke(_ pts: [CGPoint], _ color: Color, _ width: CGFloat = 2, dash: [CGFloat] = [], closed: Bool = false) {
        guard let first = pts.first else { return }
        var path = Path(); path.move(to: first)
        for p in pts.dropFirst() { path.addLine(to: p) }
        if closed { path.closeSubpath() }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash))
    }

    func curve(_ pts: [CGPoint], _ color: Color, _ width: CGFloat = 2, dash: [CGFloat] = []) {
        ctx.stroke(smooth(pts), with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
    }

    /// Catmull-Rom style smoothing through the points.
    func smooth(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard pts.count > 1 else { return path }
        path.move(to: pts[0])
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    func fill(_ path: Path, _ color: Color) { ctx.fill(path, with: .color(color)) }

    func polygon(_ pts: [CGPoint], _ color: Color) {
        var path = Path(); path.addLines(pts); path.closeSubpath(); ctx.fill(path, with: .color(color))
    }

    func arrow(_ a: CGPoint, _ b: CGPoint, _ color: Color, _ width: CGFloat = 2.5) {
        stroke([a, b], color, width)
        let ang = atan2(b.y - a.y, b.x - a.x), h = max(7, width * 3.2)
        polygon([b, CGPoint(x: b.x - h * cos(ang - .pi / 7), y: b.y - h * sin(ang - .pi / 7)),
                 CGPoint(x: b.x - h * cos(ang + .pi / 7), y: b.y - h * sin(ang + .pi / 7))], color)
    }

    static let plateColor = Color(red: 0.04, green: 0.12, blue: 0.22).opacity(0.62)

    /// Draws a label that never leaves the canvas, shrinks to `maxWidth` if a translation is long,
    /// and sits on a soft plate so lines passing behind it don't hurt legibility.
    func text(_ s: String, _ at: CGPoint, size: CGFloat = 12, color: Color = .white, weight: Font.Weight = .semibold,
              anchor: UnitPoint = .center, maxWidth: CGFloat? = nil, plate: Bool = true) {
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        func resolve(_ pt: CGFloat) -> GraphicsContext.ResolvedText {
            ctx.resolve(Text(verbatim: s).font(.system(size: pt, weight: weight)).foregroundStyle(color))
        }
        var resolved = resolve(size)
        var m = resolved.measure(in: unbounded)
        let limit = min(maxWidth ?? .greatestFiniteMagnitude, self.size.width - 8)
        if m.width > limit {
            resolved = resolve(max(7, (size * limit / m.width).rounded(.down)))
            m = resolved.measure(in: unbounded)
        }
        var o = CGPoint(x: at.x - anchor.x * m.width, y: at.y - anchor.y * m.height)
        o.x = min(max(o.x, 4), self.size.width - 4 - m.width)
        o.y = min(max(o.y, 2), self.size.height - 2 - m.height)
        let rect = CGRect(origin: o, size: m)
        if plate { ctx.fill(Path(roundedRect: rect.insetBy(dx: -3, dy: -1), cornerRadius: 4), with: .color(Self.plateColor)) }
        ctx.draw(resolved, in: rect)
    }

    func label(_ key: DiagramLabel, _ at: CGPoint, size: CGFloat = 12, color: Color = .white, anchor: UnitPoint = .center,
               maxWidth: CGFloat? = nil, plate: Bool = true) {
        text(name(key), at, size: size, color: color, anchor: anchor, maxWidth: maxWidth, plate: plate)
    }

    func circle(_ c: CGPoint, _ r: CGFloat, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
    }

    func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: Color, _ width: CGFloat = 1.5) {
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry)), with: .color(color), lineWidth: width)
    }

    func cloud(_ c: CGPoint, _ w: CGFloat, _ color: Color = .white.opacity(0.85)) {
        for (dx, dy, r) in [(-0.35, 0.1, 0.28), (0.0, -0.1, 0.38), (0.33, 0.08, 0.3), (0.12, 0.15, 0.3)] as [(CGFloat, CGFloat, CGFloat)] {
            circle(CGPoint(x: c.x + dx * w, y: c.y + dy * w), r * w, color)
        }
    }

    func sea(_ top: CGFloat, _ color: Color = Color(red: 0.1, green: 0.4, blue: 0.75).opacity(0.65)) {
        var path = Path(); path.addRect(CGRect(x: 0, y: top * size.height, width: size.width, height: size.height * (1 - top))); fill(path, color)
    }

    func ground(_ x0: CGFloat, _ x1: CGFloat, _ top: CGFloat) {
        var path = Path(); path.addRect(CGRect(x: x0 * size.width, y: top * size.height, width: (x1 - x0) * size.width, height: size.height * (1 - top)))
        fill(path, Color(red: 0.5, green: 0.42, blue: 0.25).opacity(0.85))
    }

    /// Front line with symbols on one side, pointing towards `side` (+1 left of travel direction, -1 right).
    func front(_ pts: [CGPoint], kind: String, side: CGFloat = 1) {
        let color: Color = kind == "warm" ? Palette.bad : kind == "cold" ? Color(red: 0.35, green: 0.6, blue: 1) : Color(red: 0.75, green: 0.45, blue: 0.95)
        curve(pts, color, 3)
        // Place symbols along the polyline.
        var seglens: [CGFloat] = []
        for i in 0..<(pts.count - 1) { seglens.append(hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)) }
        let total = seglens.reduce(0, +), step = max(u * 0.09, 18)
        var d = step / 2, n = 0
        while d < total {
            var acc: CGFloat = 0, i = 0
            while i < seglens.count - 1 && acc + seglens[i] < d { acc += seglens[i]; i += 1 }
            let t = (d - acc) / max(seglens[i], 0.001)
            let a = pts[i], b = pts[i + 1]
            let c = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            let ang = atan2(b.y - a.y, b.x - a.x), nx = -sin(ang) * side, ny = cos(ang) * side, s: CGFloat = max(u * 0.03, 6)
            let useWarm = kind == "warm" || (kind == "occluded" && n % 2 == 1)
            if useWarm {
                var path = Path()
                path.addArc(center: c, radius: s, startAngle: .radians(ang), endAngle: .radians(ang + .pi), clockwise: side < 0)
                path.closeSubpath()
                ctx.fill(path, with: .color(kind == "occluded" ? color : Palette.bad))
            } else {
                polygon([CGPoint(x: c.x - cos(ang) * s, y: c.y - sin(ang) * s), CGPoint(x: c.x + cos(ang) * s, y: c.y + sin(ang) * s),
                         CGPoint(x: c.x + nx * s * 1.6, y: c.y + ny * s * 1.6)], color)
            }
            d += step; n += 1
        }
    }

    func observer(_ c: CGPoint) {
        circle(c, 6, Palette.amber)
        label(.observer, CGPoint(x: c.x, y: c.y + 14), size: 11, color: Palette.amber)
    }

    func barb(_ c: CGPoint, from dirDeg: CGFloat, knots: Int, len: CGFloat, color: Color = .white) {
        // Shaft points towards where the wind comes from (screen: 0° = up/north).
        let r = (dirDeg - 90) * .pi / 180
        let tip = CGPoint(x: c.x + cos(r) * len, y: c.y + sin(r) * len)
        stroke([c, tip], color, 2)
        circle(c, 2.5, color)
        var k = knots, pos: CGFloat = 0
        let px = -sin(r), py = cos(r), f = len * 0.38
        func along(_ t: CGFloat) -> CGPoint { CGPoint(x: tip.x - cos(r) * len * t, y: tip.y - sin(r) * len * t) }
        while k >= 50 {
            let a = along(pos), b = along(pos + 0.18)
            polygon([a, b, CGPoint(x: a.x + px * f, y: a.y + py * f)], color); pos += 0.22; k -= 50
        }
        while k >= 10 {
            let a = along(pos); stroke([a, CGPoint(x: a.x + px * f + cos(r) * f * 0.3, y: a.y + py * f + sin(r) * f * 0.3)], color, 2); pos += 0.14; k -= 10
        }
        if k >= 5 {
            let a = along(max(pos, 0.14)); stroke([a, CGPoint(x: a.x + px * f * 0.5 + cos(r) * f * 0.15, y: a.y + py * f * 0.5 + sin(r) * f * 0.15)], color, 2)
        }
    }
}

// MARK: - Diagrams

enum Diagrams {
    static let iso = Color.white.opacity(0.55)
    static let blue = Color(red: 0.35, green: 0.6, blue: 1)
    static let warmTint = Palette.bad.opacity(0.18)

    static func depression(_ p: Painter, _ v: String) {
        let L = p.pt(0.36, 0.34)
        if v == "wave" {
            p.curve([p.pt(0.02, 0.5), p.pt(0.3, 0.48), p.pt(0.42, 0.36), p.pt(0.55, 0.47), p.pt(0.98, 0.5)], iso, 1.2, dash: [4, 4])
            p.front([p.pt(0.42, 0.36), p.pt(0.6, 0.45), p.pt(0.9, 0.5)], kind: "warm", side: -1)
            p.front([p.pt(0.42, 0.36), p.pt(0.3, 0.5), p.pt(0.08, 0.55)], kind: "cold", side: -1)
            p.label(.low, CGPoint(x: L.x + p.size.width * 0.06, y: L.y - 6), size: 22, color: Palette.amber)
            p.label(.coldAir, p.pt(0.5, 0.15)); p.label(.warmAir, p.pt(0.45, 0.82))
            p.arrow(p.pt(0.55, 0.75), p.pt(0.7, 0.62), Palette.amber); p.arrow(p.pt(0.3, 0.2), p.pt(0.15, 0.3), blue)
            return
        }
        for i in 1...4 {
            let r = CGFloat(i)
            p.ellipse(L, p.size.width * 0.075 * r, p.size.height * 0.08 * r, iso, 1.2)
        }
        let warm = [L, p.pt(0.55, 0.42), p.pt(0.75, 0.6), p.pt(0.86, 0.78)]
        let cold = [L, p.pt(0.32, 0.55), p.pt(0.22, 0.75), p.pt(0.12, 0.95)]
        if v != "occluded" {
            var sector = Path(); sector.move(to: L)
            sector.addLines(Array(warm.dropFirst()) + [p.pt(0.6, 1), p.pt(0.12, 0.95)] + cold.reversed())
            sector.closeSubpath()
            p.fill(sector, v == "warmSector" ? Palette.bad.opacity(0.35) : warmTint)
            p.label(.warmSector, p.pt(0.5, v == "warmSector" ? 0.84 : 0.74), size: 12, color: Palette.bad)
        }
        if v == "occluded" {
            let occ = [L, p.pt(0.5, 0.48), p.pt(0.56, 0.6)]
            p.front(occ, kind: "occluded", side: -1)
            p.front([p.pt(0.56, 0.6), p.pt(0.72, 0.72), p.pt(0.82, 0.86)], kind: "warm", side: -1)
            p.front([p.pt(0.56, 0.6), p.pt(0.44, 0.76), p.pt(0.32, 0.95)], kind: "cold", side: -1)
            p.label(.occludedFront, p.pt(0.6, 0.5), size: 12, color: Color(red: 0.75, green: 0.45, blue: 0.95), anchor: .leading)
        } else {
            p.front(warm, kind: "warm", side: -1)
            p.front(cold, kind: "cold", side: -1)
            p.label(.warmFront, p.pt(0.83, 0.55), size: 12, color: Palette.bad)
            p.label(.coldFront, p.pt(0.11, 0.72), size: 12, color: blue, maxWidth: p.size.width * 0.22)
        }
        p.label(.low, CGPoint(x: L.x, y: L.y), size: 24, color: Palette.amber)
        // Anticlockwise surface wind, crossing inwards.
        for k in 0..<6 {
            let th = CGFloat(k) * .pi / 3, rx = p.size.width * 0.26, ry = p.size.height * 0.3
            let c = CGPoint(x: L.x + rx * cos(th), y: L.y + ry * sin(th))
            let tx = sin(th), ty = -cos(th), ix = -cos(th) * 0.3, iy = -sin(th) * 0.3
            p.arrow(CGPoint(x: c.x - (tx + ix) * 12, y: c.y - (ty + iy) * 12), CGPoint(x: c.x + (tx + ix) * 12, y: c.y + (ty + iy) * 12), Palette.accent, 2)
        }
        switch v {
        case "warmSector": p.observer(p.pt(0.5, 0.62))
        case "coldFront": p.observer(p.pt(0.3, 0.62)); p.curve(cold, blue.opacity(0.5), 9)
        case "chart": p.observer(p.pt(0.55, 0.58))
        case "tracks":
            let o = p.pt(0.62, 0.55); p.observer(o)
            p.arrow(p.pt(0.05, 0.3), p.pt(0.95, 0.22), Palette.good.opacity(0.9), 2)
            p.arrow(p.pt(0.05, 0.85), p.pt(0.95, 0.85), Palette.amber.opacity(0.9), 2)
            p.label(.passesNorth, p.pt(0.5, 0.1), size: 11, color: Palette.good)
            p.label(.passesSouth, p.pt(0.56, 0.95), size: 11, color: Palette.amber)
        default: break
        }
    }

    static func pressureFeatures(_ p: Painter) {
        let L1 = p.pt(0.2, 0.3), H1 = p.pt(0.8, 0.28), L2 = p.pt(0.78, 0.78), H2 = p.pt(0.22, 0.8)
        for c in [L1, H1, L2, H2] { for i in 1...2 { p.ellipse(c, CGFloat(i) * p.u * 0.1, CGFloat(i) * p.u * 0.08, iso, 1.2) } }
        p.label(.low, L1, size: 20, color: Palette.amber); p.label(.low, L2, size: 20, color: Palette.amber)
        p.label(.high, H1, size: 20, color: Palette.accent); p.label(.high, H2, size: 20, color: Palette.accent)
        p.curve([p.pt(0.08, 0.42), p.pt(0.2, 0.6), p.pt(0.3, 0.44)], iso, 1.4)
        p.stroke([p.pt(0.2, 0.42), p.pt(0.2, 0.62)], Palette.amber, 2, dash: [5, 4])
        p.label(.trough, p.pt(0.2, 0.68), size: 11, color: Palette.amber)
        p.curve([p.pt(0.68, 0.42), p.pt(0.8, 0.6), p.pt(0.92, 0.42)], iso, 1.4)
        p.label(.ridge, p.pt(0.8, 0.66), size: 11, color: Palette.accent)
        p.label(.col, p.pt(0.5, 0.54), size: 13, color: Palette.good)
        p.label(.isobars, p.pt(0.5, 0.08), size: 11, color: iso)
    }

    static func frontSection(_ p: Painter, _ v: String) {
        p.sea(0.86)
        switch v {
        case "cold":
            p.stroke([p.pt(0.38, 0.86), p.pt(0.66, 0.15)], blue, 3)
            p.label(.coldAir, p.pt(0.8, 0.6)); p.label(.warmAir, p.pt(0.18, 0.5))
            p.cloud(p.pt(0.46, 0.3), p.u * 0.16); p.cloud(p.pt(0.42, 0.5), p.u * 0.14)
            p.label(.cumulonimbus, p.pt(0.36, 0.12), size: 11)
            for i in 0..<6 { let x = 0.33 + CGFloat(i) * 0.025; p.stroke([p.pt(x, 0.64), p.pt(x - 0.01, 0.84)], Palette.accent, 2) }
            p.label(.squall, p.pt(0.22, 0.78), size: 11, color: Palette.amber)
            p.arrow(p.pt(0.95, 0.8), p.pt(0.72, 0.8), blue)
        case "occluded":
            p.stroke([p.pt(0.1, 0.86), p.pt(0.45, 0.45)], blue, 3)
            p.stroke([p.pt(0.9, 0.86), p.pt(0.45, 0.45)], Palette.bad, 3)
            p.stroke([p.pt(0.45, 0.45), p.pt(0.45, 0.15)], Color(red: 0.75, green: 0.45, blue: 0.95), 3, dash: [6, 4])
            p.label(.warmAir, p.pt(0.45, 0.1)); p.label(.coldAir, p.pt(0.15, 0.6)); p.label(.coldAir, p.pt(0.82, 0.6))
            p.cloud(p.pt(0.55, 0.38), p.u * 0.14); p.cloud(p.pt(0.68, 0.48), p.u * 0.12)
            p.label(.occludedFront, p.pt(0.45, 0.92), size: 11, color: .white)
        default:
            p.stroke([p.pt(0.15, 0.86), p.pt(0.95, 0.12)], Palette.bad, 3)
            p.label(.coldAir, p.pt(0.75, 0.72)); p.label(.warmAir, p.pt(0.17, 0.26))
            let names: [(DiagramLabel, CGFloat, CGFloat)] = [(.cirrus, 0.88, 0.1), (.cirrostratus, 0.72, 0.24), (.altostratus, 0.54, 0.42), (.nimbostratus, 0.32, 0.62)]
            for (k, x, y) in names {
                p.stroke([p.pt(x - 0.1, y + 0.02), p.pt(x + 0.08, y - 0.02)], .white.opacity(0.75), 5)
                p.label(k, p.pt(x - 0.05, y - 0.07), size: 10)
            }
            for i in 0..<7 { let x = 0.2 + CGFloat(i) * 0.03; p.stroke([p.pt(x, 0.68), p.pt(x - 0.01, 0.84)], Palette.accent, 2) }
            p.label(.rain, p.pt(0.13, 0.76), size: 11, color: Palette.accent)
            p.arrow(p.pt(0.04, 0.5), p.pt(0.16, 0.4), Palette.amber)
        }
    }

    static func windAngle(_ p: Painter, _ v: String) {
        for y in [0.2, 0.5, 0.8] as [CGFloat] { p.stroke([p.pt(0.05, y), p.pt(0.95, y)], iso, 1.2) }
        p.label(.low, p.pt(0.5, 0.06), size: 18, color: Palette.amber); p.label(.high, p.pt(0.5, 0.95), size: 18, color: Palette.accent)
        switch v {
        case "geostrophic":
            p.arrow(p.pt(0.3, 0.5), p.pt(0.7, 0.5), .white, 3); p.label(.geostrophic, p.pt(0.3, 0.42), size: 11)
            p.arrow(p.pt(0.5, 0.55), p.pt(0.5, 0.3), Palette.amber); p.label(.pressureGradient, p.pt(0.53, 0.32), size: 10, color: Palette.amber, anchor: .leading)
            p.arrow(p.pt(0.5, 0.55), p.pt(0.5, 0.75), blue); p.label(.coriolis, p.pt(0.53, 0.72), size: 10, color: blue, anchor: .leading)
        case "curvature":
            p.label(.lighterAround, p.pt(0.25, 0.32), size: 11, color: Palette.amber)
            p.arrow(p.pt(0.15, 0.4), p.pt(0.33, 0.4), Palette.amber, 2)
            p.label(.strongerAround, p.pt(0.75, 0.62), size: 11, color: Palette.accent)
            p.arrow(p.pt(0.6, 0.68), p.pt(0.92, 0.68), Palette.accent, 3)
        default:
            p.arrow(p.pt(0.1, 0.5), p.pt(0.42, 0.5), .white.opacity(0.6), 2); p.label(.geostrophic, p.pt(0.25, 0.44), size: 10)
            p.arrow(p.pt(0.45, 0.6), p.pt(0.7, 0.53), Palette.accent, 3); p.label(.overSea, p.pt(0.6, 0.66), size: 11, color: Palette.accent)
            p.arrow(p.pt(0.62, 0.82), p.pt(0.85, 0.68), Palette.good, 3); p.label(.overLand, p.pt(0.8, 0.88), size: 11, color: Palette.good)
            p.label(.friction, p.pt(0.15, 0.7), size: 10, color: iso)
        }
    }

    static func buysBallot(_ p: Painter) {
        let o = p.pt(0.62, 0.58)
        p.ellipse(p.pt(0.16, 0.45), p.u * 0.14, p.u * 0.11, iso); p.label(.low, p.pt(0.16, 0.45), size: 22, color: Palette.amber)
        p.arrow(p.pt(0.62, 0.98), p.pt(0.62, 0.68), Palette.accent, 3); p.label(.wind, p.pt(0.7, 0.86), size: 11, color: Palette.accent, anchor: .leading)
        p.arrow(o, p.pt(0.62, 0.3), .white.opacity(0.5), 1.5)
        p.observer(o)
        p.arrow(o, p.pt(0.3, 0.47), Palette.amber, 2)
        p.label(.backToWind, p.pt(0.67, 0.44), size: 11, anchor: .leading, maxWidth: p.size.width * 0.31); p.label(.lowOnLeft, p.pt(0.42, 0.62), size: 11, color: Palette.amber, anchor: .trailing)
    }

    static func globalCirculation(_ p: Painter) {
        let c = p.pt(0.5, 0.5), r = p.u * 0.44
        p.ellipse(c, r, r, .white.opacity(0.6), 1.5)
        let bands: [(CGFloat, DiagramLabel?, Color)] = [(-0.75, .low, Palette.amber), (-0.5, .high, Palette.accent), (0, .low, Palette.amber), (0.5, .high, Palette.accent)]
        for (y, l, col) in bands {
            let yy = c.y + y * r, half = sqrt(max(r * r - (y * r) * (y * r), 0))
            p.stroke([CGPoint(x: c.x - half, y: yy), CGPoint(x: c.x + half, y: yy)], iso, 1, dash: [3, 4])
            if let l { p.label(l, CGPoint(x: c.x + half - 14, y: yy - 9), size: 12, color: col) }
        }
        for y in [-0.62, 0.62] as [CGFloat] { p.arrow(CGPoint(x: c.x - r * 0.35, y: c.y + y * r * 0.98), CGPoint(x: c.x + r * 0.35, y: c.y + y * r * 0.98 - 6), Palette.good) }
        for y in [-0.25, 0.25] as [CGFloat] { p.arrow(CGPoint(x: c.x + r * 0.4, y: c.y + y * r), CGPoint(x: c.x - r * 0.4, y: c.y + y * r * 0.4), Palette.amber) }
        p.label(.coriolis, p.pt(0.02, 0.94), size: 10, color: iso, anchor: .leading)
    }

    static func thermal(_ p: Painter, _ v: String) {
        let dayTime = v == "seaBreeze" || v == "anabatic"
        if v == "katabatic" || v == "anabatic" {
            p.sea(0.82)
            p.polygon([p.pt(0.35, 0.82), p.pt(0.75, 0.2), p.pt(1, 0.2), p.pt(1, 0.82)], Color(red: 0.5, green: 0.42, blue: 0.25).opacity(0.85))
            if v == "katabatic" {
                p.arrow(p.pt(0.78, 0.28), p.pt(0.42, 0.74), blue, 3); p.arrow(p.pt(0.4, 0.78), p.pt(0.1, 0.78), blue, 3)
                p.label(.katabatic, p.pt(0.48, 0.42), size: 13, color: blue)
            } else {
                p.arrow(p.pt(0.42, 0.72), p.pt(0.74, 0.3), Palette.amber, 2); p.label(.anabatic, p.pt(0.5, 0.42), size: 13, color: Palette.amber)
            }
            p.label(dayTime ? .day : .night, p.pt(0.1, 0.1), size: 12)
            return
        }
        p.sea(0.72); p.ground(0.5, 1, 0.68)
        p.label(.sea, p.pt(0.22, 0.88)); p.label(.land, p.pt(0.78, 0.86))
        if dayTime {
            p.circle(p.pt(0.88, 0.12), p.u * 0.06, Palette.amber); p.cloud(p.pt(0.72, 0.22), p.u * 0.12)
            p.arrow(p.pt(0.15, 0.64), p.pt(0.6, 0.64), Palette.accent, 3); p.arrow(p.pt(0.68, 0.6), p.pt(0.68, 0.3), Palette.amber)
            p.arrow(p.pt(0.6, 0.18), p.pt(0.2, 0.18), iso); p.arrow(p.pt(0.12, 0.24), p.pt(0.12, 0.56), iso)
            p.label(.seaBreeze, p.pt(0.36, 0.56), size: 13, color: Palette.accent)
        } else {
            p.text("☾", p.pt(0.12, 0.12), size: 22, plate: false)
            p.arrow(p.pt(0.85, 0.62), p.pt(0.35, 0.62), blue, 3); p.arrow(p.pt(0.2, 0.58), p.pt(0.2, 0.34), iso)
            p.arrow(p.pt(0.3, 0.26), p.pt(0.75, 0.26), iso)
            p.label(.landBreeze, p.pt(0.6, 0.54), size: 13, color: blue)
        }
    }

    static func venturi(_ p: Painter) {
        p.sea(0)
        var a = Path(); a.addEllipse(in: CGRect(origin: p.pt(0.32, 0.02), size: CGSize(width: p.size.width * 0.36, height: p.size.height * 0.36)))
        var b = Path(); b.addEllipse(in: CGRect(origin: p.pt(0.32, 0.62), size: CGSize(width: p.size.width * 0.36, height: p.size.height * 0.36)))
        p.fill(a, Color(red: 0.5, green: 0.42, blue: 0.25)); p.fill(b, Color(red: 0.5, green: 0.42, blue: 0.25))
        for y in [0.3, 0.5, 0.7] as [CGFloat] { p.arrow(p.pt(0.02, y), p.pt(0.22, y), .white.opacity(0.8), 2) }
        p.arrow(p.pt(0.3, 0.5), p.pt(0.85, 0.5), Palette.amber, 5)
        p.label(.funnelling, p.pt(0.5, 0.44), size: 13, color: Palette.amber)
        p.label(.strongerWind, p.pt(0.85, 0.58), size: 11, color: Palette.amber)
    }

    static func coastalConvergence(_ p: Painter) {
        p.sea(0); p.ground(0, 1, 0.62)
        p.stroke([p.pt(0, 0.62), p.pt(1, 0.62)], .white.opacity(0.7), 2)
        p.label(.sea, p.pt(0.08, 0.1)); p.label(.land, p.pt(0.08, 0.9))
        p.arrow(p.pt(0.1, 0.44), p.pt(0.55, 0.36), Palette.accent, 3); p.label(.overSea, p.pt(0.3, 0.33), size: 10, color: Palette.accent)
        p.arrow(p.pt(0.1, 0.84), p.pt(0.55, 0.66), Palette.good, 3); p.label(.overLand, p.pt(0.45, 0.92), size: 10, color: Palette.good)
        p.circle(p.pt(0.7, 0.56), p.u * 0.06, Palette.amber.opacity(0.5))
        p.label(.convergence, p.pt(0.8, 0.46), size: 12, color: Palette.amber); p.label(.strongerWind, p.pt(0.83, 0.74), size: 11, color: Palette.amber)
    }

    static func medWinds(_ p: Painter) {
        p.sea(0)
        let landC = Color(red: 0.5, green: 0.42, blue: 0.25).opacity(0.9)
        p.polygon([p.pt(0, 0), p.pt(1, 0), p.pt(1, 0.28), p.pt(0.82, 0.32), p.pt(0.72, 0.5), p.pt(0.62, 0.3), p.pt(0.55, 0.36), p.pt(0.48, 0.2), p.pt(0.38, 0.32), p.pt(0.3, 0.26), p.pt(0.22, 0.3), p.pt(0.12, 0.22), p.pt(0, 0.3)], landC)
        p.polygon([p.pt(0, 0.82), p.pt(1, 0.78), p.pt(1, 1), p.pt(0, 1)], landC)
        p.arrow(p.pt(0.3, 0.12), p.pt(0.3, 0.42), blue, 3); p.label(.mistral, p.pt(0.3, 0.48), size: 12, color: blue)
        p.arrow(p.pt(0.6, 0.18), p.pt(0.53, 0.32), blue, 3); p.label(.bora, p.pt(0.62, 0.4), size: 12, color: blue)
        p.arrow(p.pt(0.78, 0.36), p.pt(0.78, 0.66), Palette.accent, 3); p.label(.meltemi, p.pt(0.88, 0.56), size: 12, color: Palette.accent)
        p.arrow(p.pt(0.66, 0.86), p.pt(0.5, 0.56), Palette.amber, 3); p.label(.sirocco, p.pt(0.56, 0.74), size: 12, color: Palette.amber, anchor: .trailing)
    }

    static func fog(_ p: Painter, _ v: String) {
        switch v {
        case "radiation":
            p.ground(0, 1, 0.72); p.text("☾", p.pt(0.1, 0.12), size: 22, plate: false)
            for i in 0..<4 { var r = Path(); r.addRoundedRect(in: CGRect(origin: p.pt(0.1, 0.62 - CGFloat(i) * 0.06), size: CGSize(width: p.size.width * 0.8, height: 10)), cornerSize: CGSize(width: 5, height: 5)); p.fill(r, .white.opacity(0.4 - Double(i) * 0.08)) }
            p.label(.radiationFog, p.pt(0.5, 0.32), size: 14); p.label(.night, p.pt(0.85, 0.12))
        case "frontal":
            p.sea(0.85); p.stroke([p.pt(0.1, 0.85), p.pt(0.95, 0.2)], Palette.bad, 3)
            p.label(.warmAir, p.pt(0.35, 0.35)); p.label(.coldAir, p.pt(0.83, 0.62), anchor: .leading)
            for i in 0..<8 { let x = 0.45 + CGFloat(i) * 0.05; p.stroke([p.pt(x, 0.5 - CGFloat(i) * 0.03), p.pt(x - 0.01, 0.75)], Palette.accent.opacity(0.8), 1.5) }
            var f = Path(); f.addRect(CGRect(origin: p.pt(0.4, 0.75), size: CGSize(width: p.size.width * 0.6, height: p.size.height * 0.1))); p.fill(f, .white.opacity(0.4))
            p.label(.frontalFog, p.pt(0.7, 0.92), size: 12)
        default:
            p.sea(0.78, Color(red: 0.1, green: 0.35, blue: 0.7)); p.label(.coldSea, p.pt(0.7, 0.9), size: 12)
            for i in 0..<4 { var r = Path(); r.addRoundedRect(in: CGRect(origin: p.pt(0.38, 0.7 - CGFloat(i) * 0.06), size: CGSize(width: p.size.width * 0.6, height: 10)), cornerSize: CGSize(width: 5, height: 5)); p.fill(r, .white.opacity(0.45 - Double(i) * 0.09)) }
            p.arrow(p.pt(0.02, 0.4), p.pt(0.36, 0.55), Palette.amber, 3); p.label(.warmAir, p.pt(0.15, 0.3), color: Palette.amber)
            p.label(.advectionFog, p.pt(0.66, 0.38), size: 14)
        }
    }

    static func dewPoint(_ p: Painter) {
        p.stroke([p.pt(0.1, 0.1), p.pt(0.1, 0.85), p.pt(0.95, 0.85)], iso, 1.2)
        p.curve([p.pt(0.1, 0.2), p.pt(0.4, 0.4), p.pt(0.7, 0.55), p.pt(0.92, 0.58)], Palette.amber, 3)
        p.curve([p.pt(0.1, 0.62), p.pt(0.5, 0.6), p.pt(0.92, 0.6)], Palette.accent, 3)
        p.circle(p.pt(0.74, 0.57), 8, .white.opacity(0.5))
        p.label(.airTemperature, p.pt(0.36, 0.27), size: 11, color: Palette.amber, anchor: .leading)
        p.label(.dewPoint, p.pt(0.3, 0.7), size: 11, color: Palette.accent)
        p.label(.saturation, p.pt(0.78, 0.46), size: 11)
        p.label(.night, p.pt(0.5, 0.93), size: 10, color: iso)
    }

    static func waveRow(_ p: Painter, y: CGFloat, amp: CGFloat, len: CGFloat, x0: CGFloat = 0, x1: CGFloat = 1, color: Color = Palette.accent, breaking: Bool = false) {
        var pts: [CGPoint] = []; var x = x0
        while x <= x1 { pts.append(p.pt(x, y - amp * sin((x - x0) / len * 2 * .pi))); x += len / 12 }
        p.curve(pts, color, 2.5)
        if breaking { var x = x0 + len / 4; while x < x1 { p.circle(p.pt(x, y - amp), 3, .white); x += len } }
    }

    static func waves(_ p: Painter, _ v: String) {
        switch v {
        case "windAgainstTide":
            p.label(.windWithTide, p.pt(0.25, 0.08), size: 11)
            waveRow(p, y: 0.3, amp: 0.06, len: 0.3, x1: 0.48)
            p.arrow(p.pt(0.05, 0.42), p.pt(0.2, 0.42), Palette.accent); p.arrow(p.pt(0.28, 0.42), p.pt(0.43, 0.42), Palette.good)
            p.label(.windAgainstTide, p.pt(0.76, 0.08), size: 11, color: Palette.amber)
            waveRow(p, y: 0.32, amp: 0.12, len: 0.12, x0: 0.52, x1: 0.98, color: Palette.amber, breaking: true)
            p.arrow(p.pt(0.56, 0.46), p.pt(0.71, 0.46), Palette.accent); p.arrow(p.pt(0.94, 0.46), p.pt(0.79, 0.46), Palette.good)
            p.label(.wind, p.pt(0.63, 0.54), size: 10, color: Palette.accent); p.label(.tide, p.pt(0.86, 0.54), size: 10, color: Palette.good)
            p.label(.wavelength, p.pt(0.25, 0.62), size: 10, color: iso); p.label(.waveHeight, p.pt(0.75, 0.62), size: 10, color: iso)
        case "swell":
            waveRow(p, y: 0.35, amp: 0.05, len: 0.45, color: blue); p.label(.swell, p.pt(0.1, 0.18), color: blue)
            waveRow(p, y: 0.7, amp: 0.07, len: 0.12, color: Palette.accent); p.label(.windWaves, p.pt(0.12, 0.56), color: Palette.accent)
        default:
            p.ground(0, 0.08, 0.5)
            for (i, x) in ([0.15, 0.45, 0.75] as [CGFloat]).enumerated() {
                waveRow(p, y: 0.62, amp: 0.02 + CGFloat(i) * 0.04, len: 0.1, x0: x, x1: x + 0.22)
            }
            p.arrow(p.pt(0.1, 0.3), p.pt(0.95, 0.3), .white, 2); p.label(.wind, p.pt(0.15, 0.22), size: 11)
            p.arrow(p.pt(0.1, 0.85), p.pt(0.95, 0.85), Palette.amber, 2); p.label(.fetch, p.pt(0.52, 0.93), size: 12, color: Palette.amber)
        }
    }

    static func seaState(_ p: Painter, _ force: Int) {
        let f = CGFloat(min(max(force, 0), 12))
        p.sea(0.45)
        waveRow(p, y: 0.55, amp: 0.006 + f * 0.011, len: max(0.08, 0.28 - f * 0.012), color: .white.opacity(0.9), breaking: force >= 4)
        waveRow(p, y: 0.78, amp: 0.005 + f * 0.01, len: max(0.07, 0.24 - f * 0.012), color: .white.opacity(0.6), breaking: force >= 5)
        if force >= 7 { for i in 0..<5 { let y = 0.62 + CGFloat(i) * 0.06; p.stroke([p.pt(0.05, y), p.pt(0.95, y + 0.01)], .white.opacity(0.35), 1, dash: [10, 6]) } }
        p.text("\(p.name(.force)) \(force)", p.pt(0.5, 0.18), size: 18, color: Palette.beaufort(force), weight: .bold)
    }

    static func barograph(_ p: Painter, _ v: String) {
        p.stroke([p.pt(0.08, 0.08), p.pt(0.08, 0.85), p.pt(0.96, 0.85)], iso, 1.2)
        p.label(.hPa, p.pt(0.04, 0.1), size: 10, color: iso); p.label(.hours, p.pt(0.9, 0.93), size: 10, color: iso)
        if v == "rapidRise" {
            p.curve([p.pt(0.1, 0.3), p.pt(0.3, 0.7), p.pt(0.42, 0.78), p.pt(0.55, 0.55), p.pt(0.7, 0.25), p.pt(0.92, 0.15)], Palette.amber, 3)
            p.label(.falling, p.pt(0.25, 0.42), size: 11); p.label(.rising, p.pt(0.7, 0.45), size: 11, color: Palette.good)
            p.label(.strongerWind, p.pt(0.75, 0.12), size: 11, color: Palette.amber)
        } else {
            p.curve([p.pt(0.1, 0.2), p.pt(0.35, 0.55), p.pt(0.45, 0.62), p.pt(0.62, 0.63), p.pt(0.68, 0.5), p.pt(0.92, 0.3)], Palette.amber, 3)
            p.label(.warmFront, p.pt(0.44, 0.76), size: 10, color: Palette.bad, anchor: .trailing); p.stroke([p.pt(0.45, 0.1), p.pt(0.45, 0.85)], Palette.bad.opacity(0.6), 1, dash: [4, 4])
            p.label(.coldFront, p.pt(0.66, 0.76), size: 10, color: blue, anchor: .leading); p.stroke([p.pt(0.65, 0.1), p.pt(0.65, 0.85)], blue.opacity(0.6), 1, dash: [4, 4])
            p.label(.falling, p.pt(0.18, 0.5), size: 11); p.label(.steady, p.pt(0.55, 0.55), size: 11); p.label(.rising, p.pt(0.84, 0.22), size: 11, color: Palette.good)
        }
    }

    static func stability(_ p: Painter, _ v: String) {
        if v == "inversion" {
            p.stroke([p.pt(0.1, 0.9), p.pt(0.1, 0.05)], iso, 1.2); p.label(.height, p.pt(0.1, 0.03), size: 10, color: iso)
            p.stroke([p.pt(0.7, 0.9), p.pt(0.55, 0.55), p.pt(0.7, 0.4), p.pt(0.5, 0.05)], Palette.amber, 3)
            var band = Path(); band.addRect(CGRect(origin: p.pt(0.1, 0.4), size: CGSize(width: p.size.width * 0.85, height: p.size.height * 0.15))); p.fill(band, Palette.amber.opacity(0.15))
            p.label(.inversion, p.pt(0.85, 0.47), size: 12, color: Palette.amber)
            var haze = Path(); haze.addRect(CGRect(origin: p.pt(0.1, 0.62), size: CGSize(width: p.size.width * 0.85, height: p.size.height * 0.28))); p.fill(haze, .white.opacity(0.12))
            p.label(.high, p.pt(0.3, 0.2), size: 22, color: Palette.accent); p.arrow(p.pt(0.3, 0.26), p.pt(0.3, 0.38), Palette.accent)
            return
        }
        p.sea(0.85)
        p.label(.stable, p.pt(0.25, 0.1), size: 13, color: Palette.accent)
        var s = Path(); s.addRoundedRect(in: CGRect(origin: p.pt(0.05, 0.55), size: CGSize(width: p.size.width * 0.4, height: 14)), cornerSize: CGSize(width: 7, height: 7)); p.fill(s, .white.opacity(0.6))
        p.arrow(p.pt(0.25, 0.8), p.pt(0.25, 0.65), .white.opacity(0.6)); p.label(.stratus, p.pt(0.25, 0.45), size: 11)
        p.label(.unstable, p.pt(0.75, 0.1), size: 13, color: Palette.amber)
        p.cloud(p.pt(0.75, 0.42), p.u * 0.18); p.cloud(p.pt(0.75, 0.28), p.u * 0.14)
        p.arrow(p.pt(0.75, 0.82), p.pt(0.75, 0.55), Palette.amber, 3); p.label(.parcel, p.pt(0.71, 0.7), size: 10, color: Palette.amber, anchor: .trailing, maxWidth: p.size.width * 0.4)
    }

    static func cumulonimbus(_ p: Painter) {
        p.sea(0.86)
        p.polygon([p.pt(0.2, 0.12), p.pt(0.85, 0.12), p.pt(0.62, 0.2), p.pt(0.42, 0.2)], .white.opacity(0.85))
        p.label(.anvil, p.pt(0.75, 0.06), size: 11)
        var body = Path(); body.addRoundedRect(in: CGRect(origin: p.pt(0.38, 0.18), size: CGSize(width: p.size.width * 0.28, height: p.size.height * 0.42)), cornerSize: CGSize(width: 18, height: 18)); p.fill(body, .white.opacity(0.75))
        p.arrow(p.pt(0.44, 0.58), p.pt(0.44, 0.24), Palette.amber, 2.5); p.label(.updraught, p.pt(0.36, 0.38), size: 10, color: Palette.amber, anchor: .trailing, maxWidth: p.size.width * 0.33)
        p.arrow(p.pt(0.6, 0.3), p.pt(0.6, 0.78), blue, 2.5); p.label(.downdraught, p.pt(0.68, 0.4), size: 10, color: blue, anchor: .leading, maxWidth: p.size.width * 0.3)
        for i in 0..<6 { let x = 0.52 + CGFloat(i) * 0.025; p.stroke([p.pt(x, 0.62), p.pt(x - 0.01, 0.84)], Palette.accent, 1.5) }
        p.arrow(p.pt(0.6, 0.82), p.pt(0.95, 0.82), Palette.bad, 3); p.arrow(p.pt(0.55, 0.82), p.pt(0.2, 0.82), Palette.bad, 3)
        p.label(.gustFront, p.pt(0.86, 0.74), size: 11, color: Palette.bad); p.label(.squall, p.pt(0.2, 0.74), size: 11, color: Palette.bad)
    }

    static func windBarbs(_ p: Painter) {
        let rows: [(Int, DiagramLabel?)] = [(5, .halfBarb), (10, .fullBarb), (25, nil), (50, .pennant), (65, nil)]
        for (i, row) in rows.enumerated() {
            let x = 0.17 + CGFloat(i) * 0.18
            p.barb(p.pt(x, 0.62), from: 315, knots: row.0, len: p.u * 0.26)
            p.text("\(row.0) \(p.name(.knots))", p.pt(x, 0.88), size: 11, maxWidth: p.size.width * 0.17)
        }
        p.label(.wind, p.pt(0.5, 0.08), size: 11, color: iso)
    }

    static func synopticSymbols(_ p: Painter) {
        p.front([p.pt(0.08, 0.2), p.pt(0.62, 0.2)], kind: "warm"); p.label(.warmFront, p.pt(0.66, 0.2), size: 12, color: Palette.bad, anchor: .leading, maxWidth: p.size.width * 0.31)
        p.front([p.pt(0.08, 0.45), p.pt(0.62, 0.45)], kind: "cold"); p.label(.coldFront, p.pt(0.66, 0.45), size: 12, color: blue, anchor: .leading, maxWidth: p.size.width * 0.31)
        p.front([p.pt(0.08, 0.7), p.pt(0.62, 0.7)], kind: "occluded"); p.label(.occludedFront, p.pt(0.66, 0.7), size: 12, color: Color(red: 0.75, green: 0.45, blue: 0.95), anchor: .leading, maxWidth: p.size.width * 0.31)
        p.stroke([p.pt(0.08, 0.9), p.pt(0.62, 0.9)], .white, 2.5, dash: [8, 5]); p.label(.trough, p.pt(0.66, 0.9), size: 12, anchor: .leading, maxWidth: p.size.width * 0.31)
    }

    static func airColumn(_ p: Painter) {
        p.sea(0.88)
        for i in 0..<6 {
            let y = 0.85 - CGFloat(i) * 0.14
            var r = Path(); r.addRect(CGRect(origin: p.pt(0.35, y - 0.12), size: CGSize(width: p.size.width * 0.3, height: p.size.height * 0.12)))
            p.fill(r, Palette.accent.opacity(0.6 - Double(i) * 0.09))
        }
        p.text("1013 \(p.name(.hPa))", p.pt(0.82, 0.8), size: 12)
        p.text("≈ 900 \(p.name(.hPa))", p.pt(0.82, 0.38), size: 12, color: iso)
        p.arrow(p.pt(0.2, 0.85), p.pt(0.2, 0.1), iso, 1.5); p.label(.height, p.pt(0.12, 0.08), size: 10, color: iso)
    }

    static func airMasses(_ p: Painter) {
        p.sea(0)
        var uk = Path(); uk.addEllipse(in: CGRect(origin: p.pt(0.46, 0.4), size: CGSize(width: p.size.width * 0.1, height: p.size.height * 0.2))); p.fill(uk, Color(red: 0.5, green: 0.42, blue: 0.25))
        p.arrow(p.pt(0.1, 0.1), p.pt(0.44, 0.42), blue, 3); p.label(.polarMaritime, p.pt(0.18, 0.06), size: 11, color: blue)
        p.arrow(p.pt(0.1, 0.9), p.pt(0.44, 0.58), Palette.amber, 3); p.label(.tropicalMaritime, p.pt(0.2, 0.95), size: 11, color: Palette.amber)
        p.arrow(p.pt(0.92, 0.12), p.pt(0.58, 0.42), Palette.accent, 3); p.label(.polarContinental, p.pt(0.82, 0.06), size: 11, color: Palette.accent)
        p.arrow(p.pt(0.92, 0.9), p.pt(0.58, 0.58), Palette.bad, 3); p.label(.tropicalContinental, p.pt(0.8, 0.95), size: 11, color: Palette.bad)
    }

    static func cloudLevels(_ p: Painter) {
        p.sea(0.9)
        let tiers: [(DiagramLabel, CGFloat, [DiagramLabel])] = [(.highCloud, 0.14, [.cirrus, .cirrostratus]), (.mediumCloud, 0.42, [.altostratus]), (.lowCloud, 0.7, [.stratus, .nimbostratus, .cumulus])]
        for (tier, y, names) in tiers {
            p.stroke([p.pt(0.02, y + 0.19), p.pt(0.98, y + 0.19)], iso, 0.8, dash: [3, 5])
            p.label(tier, p.pt(0.02, y), size: 11, color: Palette.accent, anchor: .leading, maxWidth: p.size.width * 0.3)
            for (i, n) in names.enumerated() {
                let x = 0.42 + CGFloat(i) * 0.22
                p.cloud(p.pt(x, y + 0.04), p.u * 0.07, .white.opacity(0.6)); p.label(n, p.pt(x, y + 0.13), size: 9, maxWidth: p.size.width * 0.2)
            }
        }
    }

    static func visibilityScale(_ p: Painter) {
        let bands: [(DiagramLabel, Color)] = [(.visFog, Palette.bad), (.visPoor, Palette.amber), (.visModerate, Palette.accent), (.visGood, Palette.good)]
        for (i, b) in bands.enumerated() {
            let y = 0.1 + CGFloat(i) * 0.22
            var r = Path(); r.addRoundedRect(in: CGRect(origin: p.pt(0.05, y), size: CGSize(width: p.size.width * (0.42 + CGFloat(i) * 0.17), height: p.size.height * 0.15)), cornerSize: CGSize(width: 8, height: 8))
            p.fill(r, b.1.opacity(0.55)); p.label(b.0, p.pt(0.08, y + 0.075), size: 12, anchor: .leading, maxWidth: p.size.width * (0.36 + CGFloat(i) * 0.17), plate: false)
        }
    }

    static func gribGrid(_ p: Painter) {
        for r in 0..<3 { for c in 0..<4 {
            let pt = p.pt(0.14 + CGFloat(c) * 0.24, 0.2 + CGFloat(r) * 0.28)
            p.barb(pt, from: 225 + CGFloat(c) * 10, knots: 15 + r * 5 + c * 5, len: p.u * 0.13)
        } }
        p.label(.modelWind, p.pt(0.5, 0.05), size: 11, color: Palette.accent)
        p.label(.gusts, p.pt(0.5, 0.96), size: 11, color: Palette.amber)
    }

    static func forecastTimeline(_ p: Painter) {
        p.stroke([p.pt(0.05, 0.5), p.pt(0.95, 0.5)], .white, 2)
        let marks: [(CGFloat, DiagramLabel, Color)] = [(0.05, .issued, .white), (0.3, .imminent, Palette.bad), (0.58, .soon, Palette.amber), (0.86, .later, Palette.accent)]
        for (x, l, col) in marks {
            p.circle(p.pt(x, 0.5), 6, col)
            // Stagger the middle label so long translations get room without shrinking.
            p.label(l, p.pt(x, x == 0.05 ? 0.35 : (l == .soon ? 0.8 : 0.66)), size: 11, color: col, maxWidth: p.size.width * 0.44)
        }
    }

    static func passagePlan(_ p: Painter, refuge: Bool) {
        p.sea(0); p.ground(0, 1, 0.8)
        p.curve([p.pt(0.08, 0.72), p.pt(0.4, 0.55), p.pt(0.7, 0.58), p.pt(0.92, 0.72)], .white, 2, dash: [6, 5])
        p.observer(p.pt(0.08, 0.72)); p.label(.departure, p.pt(0.08, 0.92), size: 10)
        p.circle(p.pt(0.92, 0.72), 6, Palette.good); p.label(.destination, p.pt(0.88, 0.92), size: 10, color: Palette.good)
        p.front([p.pt(0.15, 0.05), p.pt(0.05, 0.4)], kind: "cold", side: -1); p.label(.front, p.pt(0.23, 0.1), size: 10, color: blue, anchor: .leading)
        p.arrow(p.pt(0.2, 0.25), p.pt(0.35, 0.25), blue, 2)
        if refuge { p.circle(p.pt(0.55, 0.78), 7, Palette.amber); p.label(.refuge, p.pt(0.55, 0.92), size: 10, color: Palette.amber) }
    }

    static func heavyWeather(_ p: Painter) {
        p.sea(0.7)
        let c = p.pt(0.5, 0.62)
        var hull = Path()
        hull.move(to: CGPoint(x: c.x - p.u * 0.18, y: c.y)); hull.addLine(to: CGPoint(x: c.x + p.u * 0.2, y: c.y - p.u * 0.03))
        hull.addLine(to: CGPoint(x: c.x + p.u * 0.14, y: c.y + p.u * 0.05)); hull.addLine(to: CGPoint(x: c.x - p.u * 0.14, y: c.y + p.u * 0.05)); hull.closeSubpath()
        p.fill(hull, .white.opacity(0.85))
        p.stroke([CGPoint(x: c.x, y: c.y), CGPoint(x: c.x, y: c.y - p.u * 0.4)], .white, 2)
        p.polygon([CGPoint(x: c.x + 2, y: c.y - p.u * 0.38), CGPoint(x: c.x + p.u * 0.16, y: c.y - p.u * 0.06), CGPoint(x: c.x + 2, y: c.y - p.u * 0.06)], Palette.accent.opacity(0.8))
        p.polygon([CGPoint(x: c.x - 2, y: c.y - p.u * 0.36), CGPoint(x: c.x - p.u * 0.2, y: c.y - p.u * 0.04), CGPoint(x: c.x - 2, y: c.y - p.u * 0.06)], Palette.amber.opacity(0.85))
        p.arrow(p.pt(0.02, 0.2), p.pt(0.25, 0.3), .white, 2.5); p.label(.wind, p.pt(0.1, 0.12), size: 11)
        p.label(.heaveTo, p.pt(0.75, 0.12), size: 13, color: Palette.amber)
        p.label(.backedHeadsail, p.pt(0.22, 0.46), size: 10, color: Palette.amber)
        p.label(.helmToWindward, p.pt(0.78, 0.86), size: 10)
    }
}
