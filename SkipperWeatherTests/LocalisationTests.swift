import XCTest
import SkipperCore
@testable import SkipperWeather

/// Runs on the simulator against the compiled bundle: proves every shipped
/// language resolves every key and that bundled content decodes.
final class LocalisationTests: XCTestCase {
    private let sampleKeys = ["tab.learn", "about.unofficialBody", "about.navBody", "about.privacyBody", "beaufort.12", "tendency.fallingVeryRapidly"]

    func testEveryLanguageBundleResolvesKeys() throws {
        for code in AppModel.supportedLanguages {
            let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"), "Missing \(code).lproj")
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in sampleKeys {
                let value = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
                XCTAssertNotEqual(value, "__MISSING__", "\(code) is missing \(key)")
                XCTAssertNotEqual(value, key, "\(code) is missing \(key)")
            }
        }
    }

    func testDisclaimerNamesNoAffiliationInEveryLanguage() throws {
        for code in AppModel.supportedLanguages {
            let bundle = try XCTUnwrap(Bundle(path: Bundle.main.path(forResource: code, ofType: "lproj")!))
            XCTAssertTrue(bundle.localizedString(forKey: "about.unofficialBody", value: nil, table: nil).contains("RYA"), code)
        }
    }

    @MainActor
    func testContentLoadsForEveryLanguage() {
        for code in AppModel.supportedLanguages {
            let loaded = AppModel.loadContent(language: code)
            XCTAssertEqual(loaded.content.modules.count, 8, code)
        }
    }

    @MainActor
    func testLanguageOverrideAndRTL() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let model = AppModel(defaults: defaults)
        model.languageOverride = "ar"
        XCTAssertEqual(model.layoutDirection, .rightToLeft)
        XCTAssertEqual(model.strings("tab.settings"), "الإعدادات")
        model.languageOverride = "el"
        XCTAssertEqual(model.layoutDirection, .leftToRight)
        XCTAssertEqual(model.strings("tab.learn"), "Μάθηση")
    }

    @MainActor
    func testProgressPersistsAndResets() {
        let suite = "test.\(UUID().uuidString)"
        let model = AppModel(defaults: UserDefaults(suiteName: suite)!)
        model.setComplete("pressure.basics")
        model.recordScore(80, scope: "all")
        model.recordScore(60, scope: "all")
        let reloaded = AppModel(defaults: UserDefaults(suiteName: suite)!)
        XCTAssertTrue(reloaded.isComplete("pressure.basics"))
        XCTAssertEqual(reloaded.bestScores["all"], 80)
        reloaded.resetProgress()
        XCTAssertEqual(reloaded.completedCount, 0)
    }
}
