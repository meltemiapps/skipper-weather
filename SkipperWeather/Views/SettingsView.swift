import SwiftUI
import SkipperCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        let t = model.strings
        NavigationStack {
            Form {
                Section(t("settings.language")) {
                    Picker(t("settings.language"), selection: $model.languageOverride) {
                        Text(t("settings.deviceLanguage")).tag(String?.none)
                        ForEach(AppModel.supportedLanguages, id: \.self) { code in
                            Text(AppModel.nativeNames[code] ?? code).tag(String?.some(code))
                        }
                    }
                }

                Section(t("settings.units")) {
                    Picker(t("settings.temperature"), selection: $model.units.temperature) {
                        ForEach(TemperatureUnit.allCases, id: \.self) { Text($0.symbol).tag($0) }
                    }
                    Picker(t("settings.pressure"), selection: $model.units.pressure) {
                        ForEach(PressureUnit.allCases, id: \.self) { Text($0.symbol).tag($0) }
                    }
                    Picker(t("settings.wind"), selection: $model.units.wind) {
                        ForEach(WindUnit.allCases, id: \.self) { u in
                            Text(u == .beaufort ? t("tools.beaufort") : u.symbol).tag(u)
                        }
                    }
                    Picker(t("settings.distance"), selection: $model.units.distance) {
                        ForEach(DistanceUnit.allCases, id: \.self) { Text($0.symbol).tag($0) }
                    }
                    Picker(t("settings.height"), selection: $model.units.height) {
                        ForEach(HeightUnit.allCases, id: \.self) { Text($0.symbol).tag($0) }
                    }
                }

                Section {
                    NavigationLink(t("settings.about")) { AboutView() }
                        .accessibilityIdentifier("settings.about")
                    Button(t("settings.resetProgress"), role: .destructive) { confirmReset = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SeaBackground())
            .navigationTitle(t("tab.settings"))
            .confirmationDialog(t("settings.resetConfirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(t("settings.resetProgress"), role: .destructive) { model.resetProgress() }
                Button(t("settings.cancel"), role: .cancel) {}
            }
        }
    }
}

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    AppMark().frame(width: 84, height: 84)
                    Text(t("app.name")).font(.title2.bold())
                    Text(t("app.subtitle")).foregroundStyle(.secondary)
                    Text(t.format("about.version", model.appVersion)).font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                section(t("about.unofficialTitle"), t("about.unofficialBody"), symbol: "exclamationmark.circle", tint: Palette.amber)
                section(t("about.navTitle"), t("about.navBody"), symbol: "location.slash", tint: Palette.bad)
                section(t("about.privacyTitle"), t("about.privacyBody"), symbol: "lock.shield", tint: Palette.good)
                section(t("about.openSourceTitle"), t("about.openSourceBody"), symbol: "chevron.left.forwardslash.chevron.right", tint: nil)

                HStack {
                    Link(t("about.privacyTitle"), destination: AppLinks.privacyPolicy)
                    Spacer()
                    Link("GitHub", destination: AppLinks.repository)
                }
                .buttonStyle(.glass)
            }
            .padding()
        }
        .screen()
        .navigationTitle(t("settings.about"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String, symbol: String, tint: Color?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(tint ?? .primary)
            Text(body).font(.subheadline)
        }
        .glassCard(tint: tint)
    }
}

/// Original mark: barometer dial over a wave. Mirrors the app icon.
struct AppMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let c = CGPoint(x: s / 2, y: s * 0.6)
            let r = s * 0.32
            var dial = Path()
            dial.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.stroke(dial, with: .color(.white), style: StrokeStyle(lineWidth: s * 0.055, lineCap: .round))
            var needle = Path()
            needle.move(to: c)
            needle.addLine(to: CGPoint(x: c.x + r * 0.55, y: c.y - r * 0.75))
            ctx.stroke(needle, with: .color(Palette.amber), style: StrokeStyle(lineWidth: s * 0.055, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - s * 0.045, y: c.y - s * 0.045, width: s * 0.09, height: s * 0.09)), with: .color(.white))
            var wave = Path()
            let y = s * 0.8
            wave.move(to: CGPoint(x: s * 0.1, y: y))
            for i in 0..<4 {
                let x0 = s * 0.1 + CGFloat(i) * s * 0.2
                wave.addQuadCurve(to: CGPoint(x: x0 + s * 0.2, y: y), control: CGPoint(x: x0 + s * 0.1, y: y - s * 0.08))
            }
            ctx.stroke(wave, with: .color(Palette.accent), style: StrokeStyle(lineWidth: s * 0.05, lineCap: .round))
        }
        .padding(10)
        .glassEffect(.regular.tint(Palette.accent.opacity(0.25)), in: .rect(cornerRadius: 22))
        .accessibilityHidden(true)
    }
}
