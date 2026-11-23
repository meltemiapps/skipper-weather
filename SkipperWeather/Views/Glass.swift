import SwiftUI

/// Deep-water backdrop that gives Liquid Glass surfaces something to refract.
struct SeaBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.13, blue: 0.21), Color(red: 0.02, green: 0.07, blue: 0.13)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.25, green: 0.7, blue: 1).opacity(0.45), .clear],
                           center: .topLeading, startRadius: 10, endRadius: 420)
            RadialGradient(colors: [Color(red: 1, green: 0.67, blue: 0.27).opacity(0.22), .clear],
                           center: .bottomTrailing, startRadius: 10, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.25)) } ?? .regular,
                         in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }

    /// Standard screen chrome: sea background, readable width on iPad.
    func screen() -> some View {
        self
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .background(SeaBackground())
    }
}

enum Palette {
    static let accent = Color(red: 0.61, green: 0.85, blue: 1.0)
    static let amber = Color(red: 1.0, green: 0.77, blue: 0.42)
    static let good = Color(red: 0.49, green: 0.89, blue: 0.6)
    static let bad = Color(red: 1.0, green: 0.42, blue: 0.42)
    /// Dark text for labels on accent-tinted prominent glass buttons.
    static let onAccent = Color(red: 0.02, green: 0.1, blue: 0.18)

    static func beaufort(_ force: Int) -> Color {
        switch force {
        case ...3: return good
        case 4...5: return accent
        case 6...7: return amber
        case 8...9: return Color(red: 1, green: 0.54, blue: 0.4)
        default: return bad
        }
    }
}
