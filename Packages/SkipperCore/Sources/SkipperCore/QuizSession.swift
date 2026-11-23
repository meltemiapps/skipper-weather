import Foundation

/// Value-type quiz state machine: select → check → next, until finished.
public struct QuizSession: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case answering, checked, finished }

    public let questions: [Question]
    public private(set) var index = 0
    public private(set) var selected: Int?
    public private(set) var phase: Phase
    public private(set) var correctCount = 0

    public init(questions: [Question]) {
        self.questions = questions
        self.phase = questions.isEmpty ? .finished : .answering
    }

    public init<G: RandomNumberGenerator>(questions: [Question], limit: Int, using generator: inout G) {
        self.init(questions: Array(questions.shuffled(using: &generator).prefix(max(limit, 0))))
    }

    public var current: Question? { questions.indices.contains(index) ? questions[index] : nil }
    public var isLast: Bool { index == questions.count - 1 }
    public var lastAnswerCorrect: Bool? {
        guard phase == .checked, let s = selected, let q = current else { return nil }
        return s == q.answer
    }
    /// 0...1
    public var score: Double { questions.isEmpty ? 0 : Double(correctCount) / Double(questions.count) }

    public mutating func select(_ option: Int) {
        guard phase == .answering, let q = current, q.options.indices.contains(option) else { return }
        selected = option
    }

    public mutating func check() {
        guard phase == .answering, let s = selected, let q = current else { return }
        if s == q.answer { correctCount += 1 }
        phase = .checked
    }

    public mutating func next() {
        guard phase == .checked else { return }
        selected = nil
        if isLast {
            phase = .finished
        } else {
            index += 1
            phase = .answering
        }
    }
}
