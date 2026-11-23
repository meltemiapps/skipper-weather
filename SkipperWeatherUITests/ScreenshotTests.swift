import XCTest

/// Captures review screenshots of the main screens in English, Greek and Arabic.
/// Run with the SkipperWeatherScreenshots scheme; PNGs go to $SCREENSHOT_DIR
/// (pass TEST_RUNNER_SCREENSHOT_DIR to xcodebuild) and are also attached to the result.
@MainActor
final class ScreenshotTests: XCTestCase {
    private let tabs: [String: [String]] = [
        "en": ["Learn", "Quiz", "Tools", "Settings"],
        "el": ["Μάθηση", "Κουίζ", "Εργαλεία", "Ρυθμίσεις"],
        "ar": ["تعلّم", "اختبار", "أدوات", "الإعدادات"],
    ]

    override func setUp() async throws { continueAfterFailure = true }

    func testEnglish() { capture("en") }
    func testGreek() { capture("el") }
    func testArabic() { capture("ar") }


    private func capture(_ lang: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-settings.language", lang]
        app.launch()
        let names = tabs[lang]!

        snap(app, lang, "1-learn")

        tapTab(app, names[0])
        if tap(app.buttons["module.pressure"]) {
            if tap(app.buttons["lesson.pressure.buysballot"]) { sleep(1); snap(app, lang, "2-lesson-diagram") }
        }

        tapTab(app, names[1]); snap(app, lang, "3-quiz")

        tapTab(app, names[2])
        if tap(app.buttons["tool.beaufort"]) { snap(app, lang, "4-beaufort") }

        tapTab(app, names[3]); snap(app, lang, "5-settings")
        if tap(app.buttons["settings.about"]) { snap(app, lang, "6-about") }
    }

    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let inBar = app.tabBars.buttons[label]
        if inBar.waitForExistence(timeout: 3) { inBar.tap(); return }
        let any = app.buttons[label].firstMatch
        if any.waitForExistence(timeout: 3) { any.tap() } else { XCTFail("Tab \(label) not found") }
    }

    @discardableResult
    private func tap(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: 5) else { XCTFail("Missing \(element)"); return false }
        element.tap()
        return true
    }

    private func snap(_ app: XCUIApplication, _ lang: String, _ name: String) {
        sleep(1)
        let shot = XCUIScreen.main.screenshot()
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let file = "\(device)-\(lang)-\(name).png"
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = file
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent(file))
        }
    }
}
