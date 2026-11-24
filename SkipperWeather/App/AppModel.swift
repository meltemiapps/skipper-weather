import SwiftUI
import Observation
import SkipperCore

/// Looks up interface strings in a specific language bundle so the in-app
/// language override works without restarting the app.
struct Localizer {
    let bundle: Bundle
    let locale: Locale

    init(language: String?, locale: Locale) {
        self.locale = locale
        if let language,
           let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = .main
        }
    }

    func callAsFunction(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: self(key), locale: locale, arguments: args)
    }
}

@MainActor
@Observable
final class AppModel {
    nonisolated static let supportedLanguages = ["en", "el", "es", "it", "fr", "pt-PT", "de", "nl", "pl", "ru", "sr", "da", "sv", "nb", "fi", "ar"]
    static let nativeNames: [String: String] = [
        "en": "English", "el": "Ελληνικά", "es": "Español", "it": "Italiano", "fr": "Français",
        "pt-PT": "Português", "de": "Deutsch", "nl": "Nederlands", "pl": "Polski", "ru": "Русский",
        "sr": "Српски", "da": "Dansk", "sv": "Svenska", "nb": "Norsk bokmål", "fi": "Suomi", "ar": "العربية"
    ]

    private enum Keys {
        static let language = "settings.language"
        static let units = "settings.units"
        static let completed = "progress.completedLessons"
        static let scores = "progress.bestScores"
    }

    private let defaults: UserDefaults

    /// nil follows the device language.
    var languageOverride: String? {
        didSet {
            defaults.set(languageOverride, forKey: Keys.language)
            reloadLanguage()
        }
    }

    var units: UnitPreferences {
        didSet {
            if let data = try? JSONEncoder().encode(units) { defaults.set(data, forKey: Keys.units) }
        }
    }

    private(set) var completedLessons: Set<String>
    /// Best quiz score in percent, keyed by module id or "all".
    private(set) var bestScores: [String: Int]
    private(set) var content: StudyContent
    private(set) var contentIsFallback = false
    private(set) var strings: Localizer

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let override = defaults.string(forKey: Keys.language).flatMap { Self.supportedLanguages.contains($0) ? $0 : nil }
        self.languageOverride = override

        if let data = defaults.data(forKey: Keys.units),
           let saved = try? JSONDecoder().decode(UnitPreferences.self, from: data) {
            self.units = saved
        } else {
            self.units = .defaults(usesUSMeasurement: Locale.current.measurementSystem == .us)
        }

        self.completedLessons = Set(defaults.stringArray(forKey: Keys.completed) ?? [])
        self.bestScores = (defaults.dictionary(forKey: Keys.scores) as? [String: Int]) ?? [:]

        let language = override ?? Bundle.main.preferredLocalizations.first ?? "en"
        self.strings = Localizer(language: override, locale: Locale(identifier: language))
        let loaded = Self.loadContent(language: language)
        self.content = loaded.content
        self.contentIsFallback = loaded.isFallback
    }

    // MARK: Language

    var effectiveLanguage: String {
        languageOverride ?? Bundle.main.preferredLocalizations.first ?? "en"
    }

    var locale: Locale { Locale(identifier: effectiveLanguage) }

    var layoutDirection: LayoutDirection {
        effectiveLanguage.hasPrefix("ar") ? .rightToLeft : .leftToRight
    }

    private func reloadLanguage() {
        strings = Localizer(language: languageOverride, locale: locale)
        let loaded = Self.loadContent(language: effectiveLanguage)
        content = loaded.content
        contentIsFallback = loaded.isFallback
    }

    /// Loads translated lesson content if bundled, otherwise English.
    static func loadContent(language: String) -> (content: StudyContent, isFallback: Bool) {
        for (code, fallback) in [(language, false), ("en", language != "en")] {
            guard let url = Bundle.main.url(forResource: "content.\(code)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let content = try? ContentLoader.decode(data) else { continue }
            return (content, fallback)
        }
        fatalError("Bundled English content is missing or invalid")
    }

    // MARK: Progress

    func isComplete(_ lessonID: String) -> Bool { completedLessons.contains(lessonID) }

    func setComplete(_ lessonID: String, _ complete: Bool = true) {
        if complete { completedLessons.insert(lessonID) } else { completedLessons.remove(lessonID) }
        defaults.set(Array(completedLessons), forKey: Keys.completed)
    }

    var completedCount: Int { content.allLessons.filter { completedLessons.contains($0.id) }.count }
    var progress: Double {
        let total = content.allLessons.count
        return total == 0 ? 0 : Double(completedCount) / Double(total)
    }
    var nextLesson: Lesson? { content.allLessons.first { !completedLessons.contains($0.id) } }

    func recordScore(_ percent: Int, scope: String) {
        if percent > (bestScores[scope] ?? -1) {
            bestScores[scope] = percent
            defaults.set(bestScores, forKey: Keys.scores)
        }
    }

    func resetProgress() {
        completedLessons = []
        bestScores = [:]
        defaults.removeObject(forKey: Keys.completed)
        defaults.removeObject(forKey: Keys.scores)
    }

    func module(containing lessonID: String) -> Module? {
        content.modules.first { $0.lessons.contains { $0.id == lessonID } }
    }

    func lesson(id: String) -> Lesson? { content.allLessons.first { $0.id == id } }

    // MARK: Formatting

    func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    func temperature(celsius: Double) -> String {
        "\(number(Convert.temperature(fromCelsius: celsius, to: units.temperature), digits: 0)) \(units.temperature.symbol)"
    }

    func pressure(hPa: Double, change: Bool = false) -> String {
        let v = Convert.pressure(fromHPa: hPa, to: units.pressure)
        let digits = units.pressure == .inchesOfMercury ? 2 : (change ? 1 : 0)
        let sign = change && v > 0 ? "+" : ""
        return "\(sign)\(number(v, digits: digits)) \(units.pressure.symbol)"
    }

    func wind(knots: Double) -> String {
        if units.wind == .beaufort { return strings.format("tools.force", Beaufort.force(knots: knots)) }
        return "\(number(Convert.wind(fromKnots: knots, to: units.wind), digits: 0)) \(units.wind.symbol)"
    }

    /// Speed band for a Beaufort force in the user's wind unit (knots when the unit is Beaufort).
    func windBand(_ band: Beaufort.Band) -> String {
        let unit: WindUnit = units.wind == .beaufort ? .knots : units.wind
        let lo = number(Convert.wind(fromKnots: Double(band.lowerKnots), to: unit), digits: 0)
        guard let upper = band.upperKnots else { return "≥ \(lo) \(unit.symbol)" }
        if band.force == 0 { return "< \(number(Convert.wind(fromKnots: 1, to: unit), digits: 0)) \(unit.symbol)" }
        let hi = number(Convert.wind(fromKnots: Double(upper), to: unit), digits: 0)
        return "\(lo)–\(hi) \(unit.symbol)"
    }

    func height(metres: Double) -> String {
        "\(number(Convert.height(fromMetres: metres, to: units.height), digits: 1)) \(units.height.symbol)"
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

enum AppLinks {
    /// Set once the public repository exists (see README "Before first release").
    static let repository = URL(string: "https://github.com/meltemiapps/skipper-weather")!
    static let support = URL(string: "https://meltemiapps.co.uk/skipper-weather/support/")!
    static let privacyPolicy = URL(string: "https://meltemiapps.co.uk/skipper-weather/privacy/")!
}
