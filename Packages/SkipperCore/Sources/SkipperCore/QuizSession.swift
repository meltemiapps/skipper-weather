import Foundation

/// One answerable item: a stand-alone question or one step of a scenario.
public struct QuizItem: Equatable, Sendable {
    public let question: Question
    /// The parent scenario, when this item is a step.
    public let scenario: Question?
    public let stepNumber: Int?
    public let stepCount: Int?
}

/// Value-type quiz state machine: respond → check → next, until finished.
/// Scenarios are flattened into their steps, each worth one mark.
public struct QuizSession: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case answering, checked, finished }

    public let items: [QuizItem]
    public private(set) var index = 0
    public private(set) var response: Response?
    public private(set) var phase: Phase
    public private(set) var correctCount = 0
    /// Ids of items answered wrongly, for review.
    public private(set) var missed: [String] = []

    public init(questions: [Question]) {
        self.items = questions.flatMap { q -> [QuizItem] in
            if q.kind == .scenario, let steps = q.steps {
                return steps.enumerated().map { QuizItem(question: $1, scenario: q, stepNumber: $0 + 1, stepCount: steps.count) }
            }
            return [QuizItem(question: q, scenario: nil, stepNumber: nil, stepCount: nil)]
        }
        self.phase = items.isEmpty ? .finished : .answering
    }

    public init<G: RandomNumberGenerator>(questions: [Question], limit: Int, using generator: inout G) {
        self.init(questions: Array(questions.shuffled(using: &generator).prefix(max(limit, 0))))
    }

    public var current: QuizItem? { items.indices.contains(index) ? items[index] : nil }
    public var isLast: Bool { index == items.count - 1 }
    public var total: Int { items.count }
    public var score: Double { items.isEmpty ? 0 : Double(correctCount) / Double(items.count) }
    public var lastAnswerCorrect: Bool? {
        guard phase == .checked, let r = response, let item = current else { return nil }
        return Grader.isCorrect(item.question, r)
    }

    public mutating func respond(_ r: Response) {
        guard phase == .answering else { return }
        response = r
    }

    /// Convenience for single-choice: select one option.
    public mutating func select(_ option: Int) { respond(.choices([option])) }

    public mutating func check() {
        guard phase == .answering, let r = response, let item = current else { return }
        if Grader.isCorrect(item.question, r) { correctCount += 1 } else { missed.append(item.question.id) }
        phase = .checked
    }

    public mutating func next() {
        guard phase == .checked else { return }
        response = nil
        if isLast { phase = .finished } else { index += 1; phase = .answering }
    }
}

/// Builds a weighted mock exam across all modules.
public enum MockExam {
    public static let questionCount = 40
    public static let durationMinutes = 60
    public static let passMark = 0.7

    /// Picks questions from every module in proportion to its bank size, until the
    /// number of marks reaches `marks`. Scenarios count by their step count.
    public static func make<G: RandomNumberGenerator>(from content: StudyContent, marks: Int = questionCount, using g: inout G) -> [Question] {
        let total = max(content.allQuestions.reduce(0) { $0 + $1.points }, 1)
        var picked: [Question] = []
        for m in content.modules {
            let bank = m.questions.reduce(0) { $0 + $1.points }
            let quota = max(1, Int((Double(bank) / Double(total) * Double(marks)).rounded()))
            var got = 0
            for q in m.questions.shuffled(using: &g) where got < quota {
                if got + q.points > quota + 1 { continue }
                picked.append(q); got += q.points
            }
        }
        return picked.shuffled(using: &g)
    }

    public static func passed(score: Double) -> Bool { score >= passMark }
}
