import SwiftUI
import SkipperCore

struct ToolsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    toolLink(t("tools.beaufort"), "wind", BeaufortToolView())
                        .accessibilityIdentifier("tool.beaufort")
                    toolLink(t("tools.tendency"), "gauge.with.dots.needle.67percent", TendencyToolView())
                    toolLink(t("tools.converter"), "arrow.left.arrow.right", ConverterToolView())
                }
                .padding()
            }
            .screen()
            .navigationTitle(t("tab.tools"))
        }
    }

    private func toolLink<D: View>(_ title: String, _ symbol: String, _ destination: D) -> some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title2).foregroundStyle(Palette.accent).frame(width: 36)
                Text(title).font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct BeaufortToolView: View {
    @Environment(AppModel.self) private var model
    @State private var selected = 6

    var body: some View {
        let t = model.strings
        let band = Beaufort.band(force: selected)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t.format("tools.force", selected)).font(.largeTitle.bold()).foregroundStyle(Palette.beaufort(selected))
                    Text(t(band.nameKey)).font(.title3.weight(.semibold))
                    LabeledContent(t("settings.wind"), value: model.windBand(band))
                    LabeledContent(t("tools.waveHeight"), value: model.height(metres: band.probableWaveMetres))
                }
                .glassCard(tint: Palette.beaufort(selected))

                Slider(value: Binding(get: { Double(selected) }, set: { selected = Int($0.rounded()) }), in: 0...12, step: 1)
                    .tint(Palette.beaufort(selected))
                    .accessibilityValue(t.format("tools.force", selected))

                ForEach(Beaufort.bands, id: \.force) { b in
                    Button { selected = b.force } label: {
                        HStack(spacing: 12) {
                            Circle().fill(Palette.beaufort(b.force)).frame(width: 10, height: 10)
                            Text("\(b.force)").font(.headline.monospacedDigit()).frame(width: 26, alignment: .leading)
                            Text(t(b.nameKey)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(model.windBand(b)).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        .glassEffect(b.force == selected ? .regular.tint(Palette.beaufort(b.force).opacity(0.3)) : .regular,
                                     in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .screen()
        .navigationTitle(t("tools.beaufort"))
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct TendencyToolView: View {
    @Environment(AppModel.self) private var model
    @State private var change = -2.0 // hPa over 3 h

    var body: some View {
        let t = model.strings
        let tendency = PressureTendency.classify(changeOver3h: change)
        let color: Color = abs(change) > 3.5 ? Palette.bad : (abs(change) >= 1.6 ? Palette.amber : Palette.good)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("tools.change3h")).font(.subheadline).foregroundStyle(.secondary)
                    Text(model.pressure(hPa: change, change: true)).font(.largeTitle.bold().monospacedDigit())
                    Text(t(tendency.key)).font(.title2.weight(.semibold)).foregroundStyle(color)
                }
                .glassCard(tint: color)

                Slider(value: $change, in: -10...10, step: 0.1)
                    .tint(color)
                    .accessibilityLabel(t("tools.change3h"))
                    .accessibilityValue("\(model.pressure(hPa: change, change: true)), \(t(tendency.key))")

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(PressureTendency.allCases, id: \.self) { tend in
                        Label(t(tend.key), systemImage: tend == tendency ? "largecircle.fill.circle" : "circle")
                            .font(.subheadline)
                            .foregroundStyle(tend == tendency ? Color.primary : .secondary)
                    }
                }
                .glassCard()
            }
            .padding()
        }
        .screen()
        .navigationTitle(t("tools.tendency"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConverterToolView: View {
    @Environment(AppModel.self) private var model

    enum Quantity: String, CaseIterable, Identifiable {
        case wind, pressure, temperature, distance, height
        var id: String { rawValue }
        var titleKey: String { "settings.\(rawValue)" }
        var units: [String] {
            switch self {
            case .wind: return WindUnit.allCases.filter { $0 != .beaufort }.map(\.rawValue)
            case .pressure: return PressureUnit.allCases.map(\.rawValue)
            case .temperature: return TemperatureUnit.allCases.map(\.rawValue)
            case .distance: return DistanceUnit.allCases.map(\.rawValue)
            case .height: return HeightUnit.allCases.map(\.rawValue)
            }
        }
    }

    @State private var quantity: Quantity = .wind
    @State private var unit = WindUnit.knots.rawValue
    @State private var value: Double? = 20

    var body: some View {
        let t = model.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker(t("tools.converter"), selection: $quantity) {
                    ForEach(Quantity.allCases) { Text(t($0.titleKey)).tag($0) }
                }
                .pickerStyle(.menu)
                .glassCard()

                HStack {
                    TextField(t("tools.value"), value: $value, format: .number.locale(model.locale))
                        .keyboardType(.numbersAndPunctuation)
                        .font(.title2.monospacedDigit())
                    Picker("", selection: $unit) {
                        ForEach(quantity.units, id: \.self) { Text(symbol(for: $0)).tag($0) }
                    }
                    .labelsHidden()
                }
                .glassCard()

                ForEach(quantity.units.filter { $0 != unit }, id: \.self) { target in
                    HStack {
                        Text(symbol(for: target)).foregroundStyle(.secondary)
                        Spacer()
                        Text(converted(to: target)).font(.title3.monospacedDigit().weight(.semibold))
                    }
                    .glassCard(cornerRadius: 18)
                }

                if quantity == .wind, let v = value {
                    let kn = Convert.windToKnots(v, from: WindUnit(rawValue: unit) ?? .knots)
                    let f = Beaufort.force(knots: kn)
                    HStack {
                        Text(t.format("tools.force", f)).font(.headline).foregroundStyle(Palette.beaufort(f))
                        Spacer()
                        Text(t(Beaufort.band(force: f).nameKey))
                    }
                    .glassCard(cornerRadius: 18, tint: Palette.beaufort(f))
                }
            }
            .padding()
        }
        .screen()
        .navigationTitle(t("tools.converter"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: quantity) { _, q in unit = q.units[0] }
    }

    private func symbol(for raw: String) -> String {
        if let u = WindUnit(rawValue: raw) { return u.symbol }
        if let u = PressureUnit(rawValue: raw) { return u.symbol }
        if let u = TemperatureUnit(rawValue: raw) { return u.symbol }
        if let u = DistanceUnit(rawValue: raw) { return u.symbol }
        if let u = HeightUnit(rawValue: raw) { return u.symbol }
        return raw
    }

    private func converted(to target: String) -> String {
        guard let v = value else { return "–" }
        let result: Double
        switch quantity {
        case .wind:
            let kn = Convert.windToKnots(v, from: WindUnit(rawValue: unit) ?? .knots)
            result = Convert.wind(fromKnots: kn, to: WindUnit(rawValue: target) ?? .knots)
        case .pressure:
            let hPa = Convert.pressureToHPa(v, from: PressureUnit(rawValue: unit) ?? .hectopascals)
            result = Convert.pressure(fromHPa: hPa, to: PressureUnit(rawValue: target) ?? .hectopascals)
        case .temperature:
            let c = Convert.temperatureToCelsius(v, from: TemperatureUnit(rawValue: unit) ?? .celsius)
            result = Convert.temperature(fromCelsius: c, to: TemperatureUnit(rawValue: target) ?? .celsius)
        case .distance:
            let nm = Convert.distanceToNauticalMiles(v, from: DistanceUnit(rawValue: unit) ?? .nauticalMiles)
            result = Convert.distance(fromNauticalMiles: nm, to: DistanceUnit(rawValue: target) ?? .nauticalMiles)
        case .height:
            let m = Convert.heightToMetres(v, from: HeightUnit(rawValue: unit) ?? .metres)
            result = Convert.height(fromMetres: m, to: HeightUnit(rawValue: target) ?? .metres)
        }
        return model.number(result, digits: 2)
    }
}
