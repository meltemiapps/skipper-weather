import XCTest
@testable import SkipperCoreTests

fileprivate extension BeaufortTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__BeaufortTests = [
        ("testBandBoundaries", testBandBoundaries),
        ("testBandsAreContiguous", testBandsAreContiguous),
        ("testTendency", testTendency)
    ]
}

fileprivate extension ContentTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__ContentTests = [
        ("testAllContentFilesMatchEnglishStructure", testAllContentFilesMatchEnglishStructure),
        ("testEnglishContentLoadsAndValidates", testEnglishContentLoadsAndValidates),
        ("testValidatorRejectsBadAnswerIndex", testValidatorRejectsBadAnswerIndex)
    ]
}

fileprivate extension QuizSessionTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__QuizSessionTests = [
        ("testEmptyQuizIsFinished", testEmptyQuizIsFinished),
        ("testFlowAndScoring", testFlowAndScoring),
        ("testSeededShuffleLimit", testSeededShuffleLimit)
    ]
}

fileprivate extension UnitsTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static let __allTests__UnitsTests = [
        ("testDistanceAndHeight", testDistanceAndHeight),
        ("testLocaleDefaults", testLocaleDefaults),
        ("testPressure", testPressure),
        ("testTemperatureRoundTrip", testTemperatureRoundTrip),
        ("testWind", testWind)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __SkipperCoreTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BeaufortTests.__allTests__BeaufortTests),
        testCase(ContentTests.__allTests__ContentTests),
        testCase(QuizSessionTests.__allTests__QuizSessionTests),
        testCase(UnitsTests.__allTests__UnitsTests)
    ]
}