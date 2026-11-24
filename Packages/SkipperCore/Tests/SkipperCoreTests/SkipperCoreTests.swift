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
    static func load(_ lang: String) throws -> StudyContent {
        try ContentLoader.decode(Data(contentsOf: contentDirectory.appendingPathComponent("content.\(lang).json")))
    }

    func testEnglishCurriculum() throws {
        let c = try Self.load("en")
        XCTAssertEqual(c.modules.count, 10)
        XCTAssertGreaterThanOrEqual(c.allLessons.count, 25)
        XCTAssertGreaterThanOrEqual(c.allQuestions.count, 80)
        for kind in [QuestionKind.single, .multi, .numeric, .order, .scenario] {
            XCTAssertTrue(c.allQuestions.contains { $0.kind == kind }, kind.rawValue)
        }
        for m in c.modules {
            for l in m.lessons { for s in l.segments { XCTAssertNotNil(s.diagram, "\(l.id): \(s.heading) has no diagram") } }
        }
    }

    func testTranslationsMatchEnglishStructure() throws {
        let en = try Self.load("en")
        let files = try FileManager.default.contentsOfDirectory(at: Self.contentDirectory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("content.") && $0.pathExtension == "json" }
        for f in files {
            let c = try ContentLoader.decode(Data(contentsOf: f))
            XCTAssertEqual(ContentLoader.structureMatches(c, en), [], f.lastPathComponent)
        }
    }

    func testAnswerKeysGradeAsCorrect() throws {
        let c = try Self.load("en")
        func check(_ q: Question) {
            switch q.kind {
            case .single, .multi: XCTAssertTrue(Grader.isCorrect(q, .choices(q.answers!)), q.id)
            case .order: XCTAssertTrue(Grader.isCorrect(q, .order(q.answers!)), q.id)
            case .numeric: XCTAssertTrue(Grader.isCorrect(q, .number(q.numeric!.value)), q.id)
            case .scenario: q.steps!.forEach(check)
            }
        }
        c.allQuestions.forEach(check)
    }
}

final class GraderTests: XCTestCase {
    private func q(_ kind: QuestionKind, answers: [Int]? = nil, numeric: NumericAnswer? = nil) -> Question {
        Question(id: "x", kind: kind, context: nil, prompt: "p", diagram: nil, options: ["a", "b", "c", "d"],
                 answers: answers, numeric: numeric, optionExplanations: nil, explanation: "e", steps: nil)
    }

    func testKinds() {
        XCTAssertTrue(Grader.isCorrect(q(.single, answers: [2]), .choices([2])))
        XCTAssertFalse(Grader.isCorrect(q(.single, answers: [2]), .choices([1])))
        XCTAssertTrue(Grader.isCorrect(q(.multi, answers: [0, 2]), .choices([2, 0])))
        XCTAssertFalse(Grader.isCorrect(q(.multi, answers: [0, 2]), .choices([0])))
        XCTAssertTrue(Grader.isCorrect(q(.order, answers: [3, 1, 0, 2]), .order([3, 1, 0, 2])))
        XCTAssertFalse(Grader.isCorrect(q(.order, answers: [3, 1, 0, 2]), .order([1, 3, 0, 2])))
        let bearing = q(.numeric, numeric: NumericAnswer(value: 350, tolerance: 15, unit: "°"))
        XCTAssertTrue(Grader.isCorrect(bearing, .number(5)), "wraps through north")
        XCTAssertFalse(Grader.isCorrect(bearing, .number(20)))
        let hpa = q(.numeric, numeric: NumericAnswer(value: 1008, tolerance: 0, unit: "hPa"))
        XCTAssertTrue(Grader.isCorrect(hpa, .number(1008)))
        XCTAssertFalse(Grader.isCorrect(hpa, .number(.nan)))
    }

    func testMockExamCoversModulesAndMarks() throws {
        let c = try ContentTests.load("en")
        var g = SeededGenerator(seed: 7)
        let exam = MockExam.make(from: c, using: &g)
        let marks = exam.reduce(0) { $0 + $1.points }
        XCTAssertGreaterThanOrEqual(marks, 35)
        XCTAssertLessThanOrEqual(marks, 50)
        let modules = Set(exam.compactMap { q in c.modules.first { $0.questions.contains(q) }?.id })
        XCTAssertEqual(modules.count, c.modules.count)
        XCTAssertEqual(Set(exam.map(\.id)).count, exam.count)
    }
}

final class QuizSessionTests: XCTestCase {
    private func q(_ id: String, answer: Int) -> Question {
        Question(id: id, kind: .single, context: nil, prompt: id, diagram: nil, options: ["a", "b", "c", "d"],
                 answers: [answer], numeric: nil, optionExplanations: nil, explanation: "", steps: nil)
    }

    func testFlowAndScoring() {
        var s = QuizSession(questions: [q("1", answer: 0), q("2", answer: 2)])
        s.check()
        XCTAssertEqual(s.phase, .answering)
        s.select(0); s.check()
        XCTAssertEqual(s.lastAnswerCorrect, true)
        s.next(); s.select(1); s.check()
        XCTAssertEqual(s.lastAnswerCorrect, false)
        s.next()
        XCTAssertEqual(s.phase, .finished)
        XCTAssertEqual(s.score, 0.5)
        XCTAssertEqual(s.missed, ["2"])
    }

    func testScenarioFlattensIntoSteps() {
        let scen = Question(id: "s", kind: .scenario, context: "ctx", prompt: "p", diagram: nil, options: nil, answers: nil,
                            numeric: nil, optionExplanations: nil, explanation: "e", steps: [q("s1", answer: 0), q("s2", answer: 1)])
        let s = QuizSession(questions: [scen, q("3", answer: 0)])
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.current?.scenario?.id, "s")
        XCTAssertEqual(s.current?.stepCount, 2)
    }

    func testSeededShuffleLimit() {
        var g = SeededGenerator(seed: 42)
        let s = QuizSession(questions: (0..<20).map { q("\($0)", answer: 0) }, limit: 10, using: &g)
        XCTAssertEqual(s.total, 10)
    }

    func testEmptyQuizIsFinished() {
        XCTAssertEqual(QuizSession(questions: []).phase, .finished)
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
