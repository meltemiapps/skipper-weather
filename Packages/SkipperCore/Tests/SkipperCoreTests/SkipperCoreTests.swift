import XCTest
@testable import SkipperCore

final class UnitsTests: XCTestCase {
    func testTemperatureRoundTrip() {
        XCTAssertEqual(Convert.temperature(fromCelsius: 0, to: .fahrenheit), 32, accuracy: 1e-9)
        XCTAssertEqual(Convert.temperature(fromCelsius: 100, to: .fahrenheit), 212, accuracy: 1e-9)
        XCTAssertEqual(Convert.temperatureToCelsius(-40, from: .fahrenheit), -40, accuracy: 1e-9)
        for c in stride(from: -30.0, through: 45.0, by: 2.5) {
            let f = Convert.temperature(fromCelsius: c, to: .fahrenheit)
            XCTAssertEqual(Convert.temperatureToCelsius(f, from: .fahrenheit), c, accuracy: 1e-9)
        }
    }

    func testPressure() {
        XCTAssertEqual(Convert.pressure(fromHPa: 1013.25, to: .millibars), 1013.25)
        XCTAssertEqual(Convert.pressure(fromHPa: 1013.25, to: .inchesOfMercury), 29.92, accuracy: 0.005)
        XCTAssertEqual(Convert.pressureToHPa(29.92, from: .inchesOfMercury), 1013.2, accuracy: 0.1)
    }

    func testWind() {
        XCTAssertEqual(Convert.wind(fromKnots: 10, to: .kilometresPerHour), 18.52, accuracy: 1e-9)
        XCTAssertEqual(Convert.wind(fromKnots: 10, to: .metresPerSecond), 5.144, accuracy: 0.001)
        XCTAssertEqual(Convert.wind(fromKnots: 10, to: .milesPerHour), 11.508, accuracy: 0.001)
        XCTAssertEqual(Convert.wind(fromKnots: 25, to: .beaufort), 6)
        for unit in WindUnit.allCases where unit != .beaufort {
            let v = Convert.wind(fromKnots: 33.3, to: unit)
            XCTAssertEqual(Convert.windToKnots(v, from: unit), 33.3, accuracy: 1e-9, "\(unit)")
        }
        XCTAssertEqual(Convert.windToKnots(6, from: .beaufort), 24.5)
    }

    func testDistanceAndHeight() {
        XCTAssertEqual(Convert.distance(fromNauticalMiles: 1, to: .kilometres), 1.852, accuracy: 1e-9)
        XCTAssertEqual(Convert.distance(fromNauticalMiles: 1, to: .miles), 1.15078, accuracy: 1e-5)
        XCTAssertEqual(Convert.distanceToNauticalMiles(1.852, from: .kilometres), 1, accuracy: 1e-9)
        XCTAssertEqual(Convert.height(fromMetres: 3, to: .feet), 9.8425, accuracy: 1e-4)
        XCTAssertEqual(Convert.heightToMetres(10, from: .feet), 3.048, accuracy: 1e-9)
    }

    func testLocaleDefaults() {
        let uk = UnitPreferences.defaults(usesUSMeasurement: false)
        XCTAssertEqual(uk.temperature, .celsius)
        XCTAssertEqual(uk.pressure, .hectopascals)
        XCTAssertEqual(uk.wind, .knots)
        XCTAssertEqual(uk.distance, .nauticalMiles)
        let us = UnitPreferences.defaults(usesUSMeasurement: true)
        XCTAssertEqual(us.temperature, .fahrenheit)
        XCTAssertEqual(us.pressure, .inchesOfMercury)
        XCTAssertEqual(us.height, .feet)
        XCTAssertEqual(us.wind, .knots, "Marine default stays knots")
    }
}

final class BeaufortTests: XCTestCase {
    func testBandBoundaries() {
        let cases: [(Double, Int)] = [
            (0, 0), (0.4, 0), (1, 1), (3, 1), (4, 2), (6, 2), (7, 3), (10, 3), (11, 4),
            (16, 4), (17, 5), (21, 5), (22, 6), (27, 6), (28, 7), (33, 7), (34, 8),
            (40, 8), (41, 9), (47, 9), (48, 10), (55, 10), (56, 11), (63, 11), (64, 12), (120, 12),
            (27.4, 6), (27.6, 7), (-5, 0), (.nan, 0)
        ]
        for (kn, f) in cases {
            XCTAssertEqual(Beaufort.force(knots: kn), f, "\(kn) kn")
        }
    }

    func testBandsAreContiguous() {
        XCTAssertEqual(Beaufort.bands.count, 13)
        for (a, b) in zip(Beaufort.bands, Beaufort.bands.dropFirst()) {
            XCTAssertEqual(a.upperKnots.map { $0 + 1 }, b.lowerKnots)
            XCTAssertLessThanOrEqual(a.probableWaveMetres, b.probableWaveMetres)
        }
        XCTAssertNil(Beaufort.bands.last?.upperKnots)
    }

    func testTendency() {
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 0), .steady)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 0.05), .steady)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 1.0), .risingSlowly)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: -1.5), .fallingSlowly)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 2.0), .rising)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: -3.5), .falling)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 4.0), .risingQuickly)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: -6.0), .fallingQuickly)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: -7.0), .fallingVeryRapidly)
        XCTAssertEqual(PressureTendency.classify(changeOver3h: 6.5), .risingVeryRapidly)
    }
}

final class ContentTests: XCTestCase {
    static var contentDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SkipperWeather/Resources/Content")
    }

    func testEnglishContentLoadsAndValidates() throws {
        let data = try Data(contentsOf: Self.contentDirectory.appendingPathComponent("content.en.json"))
        let content = try ContentLoader.decode(data)
        XCTAssertEqual(content.language, "en")
        XCTAssertEqual(content.modules.count, 8)
        XCTAssertGreaterThanOrEqual(content.allLessons.count, 16)
        XCTAssertGreaterThanOrEqual(content.allQuestions.count, 40)
    }

    func testAllContentFilesMatchEnglishStructure() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.contentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("content.") && $0.pathExtension == "json" }
        let en = try ContentLoader.decode(Data(contentsOf: Self.contentDirectory.appendingPathComponent("content.en.json")))
        for file in files {
            let c = try ContentLoader.decode(Data(contentsOf: file))
            XCTAssertEqual(c.modules.map(\.id), en.modules.map(\.id), file.lastPathComponent)
            XCTAssertEqual(c.allLessons.map(\.id), en.allLessons.map(\.id), file.lastPathComponent)
            XCTAssertEqual(c.allQuestions.map(\.id), en.allQuestions.map(\.id), file.lastPathComponent)
            XCTAssertEqual(c.allQuestions.map(\.answer), en.allQuestions.map(\.answer), "Answer keys must not drift in \(file.lastPathComponent)")
        }
    }

    func testValidatorRejectsBadAnswerIndex() {
        let bad = StudyContent(language: "en", modules: [
            Module(id: "m", title: "t", summary: "s", symbol: "wind",
                   lessons: [Lesson(id: "l", title: "t", paragraphs: ["p"], keyPoints: [], diagram: nil)],
                   questions: [Question(id: "q", prompt: "p", options: ["a", "b"], answer: 5, explanation: "e")])
        ])
        XCTAssertThrowsError(try ContentLoader.validate(bad))
    }
}

final class QuizSessionTests: XCTestCase {
    private func q(_ id: String, answer: Int) -> Question {
        Question(id: id, prompt: id, options: ["a", "b", "c", "d"], answer: answer, explanation: "")
    }

    func testFlowAndScoring() {
        var s = QuizSession(questions: [q("1", answer: 0), q("2", answer: 2)])
        XCTAssertEqual(s.phase, .answering)
        s.check() // nothing selected: no-op
        XCTAssertEqual(s.phase, .answering)
        s.select(0); s.check()
        XCTAssertEqual(s.lastAnswerCorrect, true)
        s.select(3) // ignored once checked
        s.next()
        XCTAssertEqual(s.index, 1)
        s.select(1); s.check()
        XCTAssertEqual(s.lastAnswerCorrect, false)
        s.next()
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.correctCount, 1)
        XCTAssertEqual(s.score, 0.5)
    }

    func testEmptyQuizIsFinished() {
        XCTAssertEqual(QuizSession(questions: []).phase, .finished)
    }

    func testSeededShuffleLimit() {
        var g = SeededGenerator(seed: 42)
        let s = QuizSession(questions: (0..<20).map { q("\($0)", answer: 0) }, limit: 10, using: &g)
        XCTAssertEqual(s.questions.count, 10)
        XCTAssertEqual(Set(s.questions.map(\.id)).count, 10)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
