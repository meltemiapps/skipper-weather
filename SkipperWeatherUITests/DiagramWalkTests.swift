import XCTest

/// Build 2 visual check: opens every lesson, captures every diagram, and one question
/// of each kind plus the mock exam start screen. Configure with environment variables:
/// WALK_LANGS (default "en,el,es"), WALK_SIZE (UIContentSizeCategory name, default L),
/// SCREENSHOT_DIR (where PNGs are written). Run with the SkipperWeatherScreenshots scheme.
@MainActor
final class DiagramWalkTests: XCTestCase {
    private let modules: [String: [String]] = [
        "atmosphere": ["atmosphere.pressure", "atmosphere.barometer", "atmosphere.airmasses"],
        "wind": ["wind.global", "wind.surface", "wind.buysballot"],
        "systems": ["systems.lifecycle", "systems.highs", "systems.features"],
        "fronts": ["fronts.warm", "fronts.cold", "fronts.occluded"],
        "clouds": ["clouds.stability", "clouds.cb"],
        "local": ["local.thermal", "local.topography", "local.med"],
        "fog": ["fog.dewpoint", "fog.types", "fog.seamanship"],
        "sea": ["sea.waves", "sea.tide", "sea.reading"],
        "forecasts": ["forecasts.charts", "forecasts.grib", "forecasts.language", "forecasts.reconcile"],
        "planning": ["planning.window", "planning.gonogo", "planning.heavy"],
    ]
    private let order = ["atmosphere", "wind", "systems", "fronts", "clouds", "local", "fog", "sea", "forecasts", "planning"]

    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var langs: [String] { (env["WALK_LANGS"] ?? "en,el,es").split(separator: ",").map(String.init) }
    private var size: String { env["WALK_SIZE"] ?? "UICTContentSizeCategoryL" }
    private var sizeTag: String { size.contains("Accessibility") ? "ax" : "std" }

    override func setUp() async throws { continueAfterFailure = true }

    func testWalkLessons() {
        for lang in langs {
            let app = launch(lang)
            for module in order {
                guard scrollTo(app, app.buttons["module.\(module)"]) else { XCTFail("module \(module)"); continue }
                tapTop(app.buttons["module.\(module)"])
                for lesson in modules[module]! {
                    guard scrollTo(app, app.buttons["lesson.\(lesson)"]) else { XCTFail("lesson \(lesson)"); continue }
                    tapTop(app.buttons["lesson.\(lesson)"])
                    walkLesson(app, lang, lesson)
                    back(app)
                }
                back(app)
            }
            app.terminate()
        }
    }

    func testWalkQuiz() {
        for lang in langs {
            let app = launch(lang)
            tapTab(app, ["en": "Quiz", "el": "Κουίζ", "es": "Test"][lang]!)
            if scrollTo(app, app.buttons["quiz.mock"]) {
                tapTop(app.buttons["quiz.mock"])
                sleep(2)
                snap(app.screenshot(), "\(lang)-\(sizeTag)-mock-start", full: true)
                back(app)
            }
            guard scrollTo(app, app.buttons["quiz.scope.sea"]) else { XCTFail("sea quiz"); continue }
            tapTop(app.buttons["quiz.scope.sea"])
            var seen = Set<String>()
            for _ in 0..<20 {
                let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'question.'")).firstMatch
                guard card.waitForExistence(timeout: 5) else {
                    if let dir = env["SCREENSHOT_DIR"] { try? app.debugDescription.write(toFile: dir + "/quiz-\(lang)-tree.txt", atomically: true, encoding: .utf8) }
                    break
                }
                let kind = String(card.identifier.dropFirst("question.".count))
                answer(app, kind)
                if !seen.contains(kind) {
                    seen.insert(kind)
                    snapScrolling(app, "\(lang)-\(sizeTag)-question-\(kind)")
                }
                let action = app.buttons["quiz.action"]
                guard scrollTo(app, action), action.isEnabled else { break }
                action.tap() // check
                if !scrollTo(app, action) { break }
                action.tap() // next / finish
            }
            XCTAssertEqual(seen, ["single", "multi", "numeric", "order", "scenario"], lang)
            app.terminate()
        }
    }

    // MARK: helpers

    private func launch(_ lang: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-settings.language", lang,
                               "-UIPreferredContentSizeCategoryName", size]
        app.launch()
        return app
    }

    private func walkLesson(_ app: XCUIApplication, _ lang: String, _ lesson: String) {
        var captured = Set<String>()
        var page = 0
        let done = app.buttons["lesson.complete"]
        repeat {
            snap(app.screenshot(), "\(lang)-\(sizeTag)-\(lesson)-p\(page)", full: true)
            let diagrams = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'diagram.'"))
            for i in 0..<diagrams.count {
                let d = diagrams.element(boundBy: i)
                guard d.exists, !captured.contains(d.identifier), fullyVisible(app, d) else { continue }
                captured.insert(d.identifier)
                snap(d.screenshot(), "\(lang)-\(sizeTag)-\(lesson)-\(d.identifier)")
            }
            if done.exists && fullyVisible(app, done) { break }
            step(app)
            page += 1
        } while page < 60
        // Diagrams that were never fully on screen between steps: scroll back to each one.
        let all = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'diagram.'"))
        for i in 0..<all.count {
            let d = all.element(boundBy: i)
            guard d.exists, !captured.contains(d.identifier) else { continue }
            var n = 0
            while !fullyVisible(app, d) && n < 30 { stepBack(app); n += 1 }
            if fullyVisible(app, d) {
                captured.insert(d.identifier)
                snap(d.screenshot(), "\(lang)-\(sizeTag)-\(lesson)-\(d.identifier)")
            } else { XCTFail("could not capture \(d.identifier) in \(lesson)") }
        }
    }

    private func stepBack(_ app: XCUIApplication) {
        let w = app.windows.firstMatch
        let from = w.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45))
        let to = w.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.62))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: 600, thenHoldForDuration: 0.3)
    }

    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let inBar = app.tabBars.buttons[label]
        if inBar.waitForExistence(timeout: 3) { inBar.tap(); return }
        let any = app.buttons[label].firstMatch
        if any.waitForExistence(timeout: 3) { any.tap() } else { XCTFail("Tab \(label) not found") }
    }

    private func answer(_ app: XCUIApplication, _ kind: String) {
        let first = app.buttons["quiz.option.0"]
        if first.exists { if scrollTo(app, first) { first.tap() }; return }
        let field = app.textFields["quiz.number"]
        if field.exists, scrollTo(app, field) { field.tap(); field.typeText("1"); app.keyboards.buttons.firstMatch.tapIfExists() }
    }

    private func snapScrolling(_ app: XCUIApplication, _ name: String) {
        // Top of the card, then the rest of it.
        for i in 0..<4 {
            snap(app.screenshot(), "\(name)-\(i)", full: true)
            let action = app.buttons["quiz.action"]
            if action.exists && fullyVisible(app, action) { break }
            step(app)
        }
        for _ in 0..<4 { app.swipeDown(velocity: .fast) }
    }

    /// Scrolls content up by about a third of the screen, slowly enough to avoid momentum.
    private func step(_ app: XCUIApplication) {
        let w = app.windows.firstMatch
        let from = w.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.72))
        let to = w.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.37))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: 600, thenHoldForDuration: 0.3)
    }

    private func fullyVisible(_ app: XCUIApplication, _ e: XCUIElement) -> Bool {
        let w = app.windows.firstMatch.frame, f = e.frame
        return !f.isEmpty && w.contains(f) && f.minY > 90 && f.maxY < w.maxY - 70
    }

    /// Brings an element on screen: fully visible if it fits, otherwise with its top edge in view
    /// (rows can be taller than the screen at accessibility text sizes). Scrolls in either direction.
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ e: XCUIElement) -> Bool {
        guard e.waitForExistence(timeout: 5) else { return false }
        let h = app.windows.firstMatch.frame.height
        func onScreen() -> Bool {
            let f = e.frame
            return fullyVisible(app, e) || (f.minY > 100 && f.minY < h - 260)
        }
        var n = 0
        while !onScreen() && n < 40 {
            if e.frame.minY < 100 { stepBack(app) } else { step(app) }
            n += 1
        }
        return onScreen()
    }

    /// Taps just inside the top of the element, which is on screen even when the element is taller than the screen.
    private func tapTop(_ e: XCUIElement) {
        let dy = min(0.5, 24 / max(e.frame.height, 1))
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy)).tap()
    }

    private func back(_ app: XCUIApplication) {
        let b = app.navigationBars.buttons.element(boundBy: 0)
        if b.waitForExistence(timeout: 3) { b.tap() }
    }

    private func snap(_ shot: XCUIScreenshot, _ name: String, full: Bool = false) {
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = env["SCREENSHOT_DIR"], !dir.isEmpty else { return }
        let sub = URL(fileURLWithPath: dir).appendingPathComponent(full ? "screens" : "diagrams")
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: sub.appendingPathComponent("\(name).png"))
    }
}

private extension XCUIElement {
    func tapIfExists() { if exists && isHittable { tap() } }
}
