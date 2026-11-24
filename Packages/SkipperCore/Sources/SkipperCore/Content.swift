import Foundation

// MARK: - Content model (schema v2)

public struct StudyContent: Codable, Equatable, Sendable {
    public let language: String
    public let glossary: [GlossaryEntry]
    /// Text drawn inside diagrams, keyed by `DiagramLabel.rawValue`.
    public let diagramLabels: [String: String]
    public let modules: [Module]

    public func module(id: String) -> Module? { modules.first { $0.id == id } }
    public var allLessons: [Lesson] { modules.flatMap(\.lessons) }
    public var allQuestions: [Question] { modules.flatMap(\.questions) }
    public func label(_ key: DiagramLabel) -> String { diagramLabels[key.rawValue] ?? key.rawValue }
}

public struct GlossaryEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let term: String
    public let definition: String
}

public struct Module: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let summary: String
    /// SF Symbol name.
    public let symbol: String
    public let lessons: [Lesson]
    public let questions: [Question]
}

public struct Lesson: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let segments: [Segment]
}

public struct Segment: Codable, Equatable, Sendable {
    public let heading: String
    public let paragraphs: [String]
    public let keyPoints: [String]?
    public let diagram: DiagramRef?
}

/// A reference to a native diagram, optionally focused on one stage or variant.
public struct DiagramRef: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let variant: String?

    public init(id: String, variant: String? = nil) {
        self.id = id
        self.variant = variant
    }
}

public enum QuestionKind: String, Codable, Sendable {
    case single, multi, numeric, order, scenario
}

public struct NumericAnswer: Codable, Equatable, Sendable {
    public let value: Double
    public let tolerance: Double
    /// Unit symbol shown beside the input, e.g. "°", "hPa", "kn".
    public let unit: String
}

public struct Question: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: QuestionKind
    /// Scenario context shown above the prompt (or above all steps).
    public let context: String?
    public let prompt: String
    public let diagram: DiagramRef?
    public let options: [String]?
    /// single: [i]; multi: all correct indices; order: option indices in correct order.
    public let answers: [Int]?
    public let numeric: NumericAnswer?
    /// One explanation per option, explaining why it is right or wrong.
    public let optionExplanations: [String]?
    public let explanation: String
    /// Scenario steps, each a single/multi/numeric/order question sharing the context.
    public let steps: [Question]?

    /// Marks: one per answerable part.
    public var points: Int { kind == .scenario ? (steps?.count ?? 0) : 1 }
}

// MARK: - Responses and grading

public enum Response: Equatable, Sendable {
    case choices([Int])
    case number(Double)
    case order([Int])
}

public enum Grader {
    public static func isCorrect(_ q: Question, _ r: Response) -> Bool {
        switch (q.kind, r) {
        case (.single, .choices(let c)):
            return c.count == 1 && c.first == q.answers?.first
        case (.multi, .choices(let c)):
            return Set(c) == Set(q.answers ?? []) && !c.isEmpty
        case (.numeric, .number(let v)):
            guard let n = q.numeric, v.isFinite else { return false }
            if n.unit == "°" {
                // Bearings wrap around 360°.
                let d = abs((v - n.value).truncatingRemainder(dividingBy: 360))
                return min(d, 360 - d) <= n.tolerance
            }
            return abs(v - n.value) <= n.tolerance
        case (.order, .order(let o)):
            return o == (q.answers ?? [])
        default:
            return false
        }
    }
}

// MARK: - Validation

public enum ContentError: Error, Equatable, CustomStringConvertible {
    case invalid(String)
    public var description: String { if case .invalid(let s) = self { return s }; return "" }
}

public enum ContentLoader {
    public static let knownDiagrams: Set<String> = [
        "depression", "pressureFeatures", "frontSection", "windAngle", "buysBallot", "globalCirculation",
        "thermal", "venturi", "coastalConvergence", "medWinds", "fog", "dewPoint", "waves", "seaState",
        "barograph", "stability", "cumulonimbus", "windBarbs", "synopticSymbols",
        "airColumn", "airMasses", "cloudLevels", "visibilityScale", "gribGrid", "forecastTimeline", "passagePlan", "heavyWeather"
    ]

    public static func decode(_ data: Data) throws -> StudyContent {
        let content = try JSONDecoder().decode(StudyContent.self, from: data)
        try validate(content)
        return content
    }

    public static func validate(_ content: StudyContent) throws {
        var ids = Set<String>()
        func unique(_ id: String) throws {
            guard ids.insert(id).inserted else { throw ContentError.invalid("Duplicate id \(id)") }
        }
        func checkDiagram(_ d: DiagramRef?, _ owner: String) throws {
            if let d, !knownDiagrams.contains(d.id) { throw ContentError.invalid("\(owner): unknown diagram \(d.id)") }
        }
        for key in DiagramLabel.allCases where (content.diagramLabels[key.rawValue] ?? "").isEmpty {
            throw ContentError.invalid("Missing diagram label \(key.rawValue)")
        }
        guard !content.modules.isEmpty else { throw ContentError.invalid("No modules") }
        for g in content.glossary { try unique("glossary.\(g.id)") }
        for m in content.modules {
            try unique(m.id)
            guard !m.lessons.isEmpty else { throw ContentError.invalid("\(m.id) has no lessons") }
            for l in m.lessons {
                try unique(l.id)
                guard !l.segments.isEmpty else { throw ContentError.invalid("\(l.id) has no segments") }
                for s in l.segments {
                    guard !s.paragraphs.isEmpty else { throw ContentError.invalid("\(l.id) has an empty segment") }
                    try checkDiagram(s.diagram, l.id)
                }
            }
            for q in m.questions { try validate(q, unique: unique, checkDiagram: checkDiagram) }
        }
    }

    private static func validate(_ q: Question, unique: (String) throws -> Void, checkDiagram: (DiagramRef?, String) throws -> Void) throws {
        try unique(q.id)
        try checkDiagram(q.diagram, q.id)
        let opts = q.options ?? []
        switch q.kind {
        case .single, .multi, .order:
            guard opts.count >= 2, Set(opts).count == opts.count else { throw ContentError.invalid("\(q.id): bad options") }
            let a = q.answers ?? []
            guard !a.isEmpty, a.allSatisfy(opts.indices.contains) else { throw ContentError.invalid("\(q.id): bad answers") }
            if q.kind == .single, a.count != 1 { throw ContentError.invalid("\(q.id): single needs one answer") }
            if q.kind == .order, Set(a) != Set(opts.indices) { throw ContentError.invalid("\(q.id): order must use every option") }
            if let e = q.optionExplanations, e.count != opts.count { throw ContentError.invalid("\(q.id): explanation count") }
        case .numeric:
            guard let n = q.numeric, n.tolerance >= 0 else { throw ContentError.invalid("\(q.id): numeric missing") }
        case .scenario:
            guard let steps = q.steps, !steps.isEmpty, q.context != nil else { throw ContentError.invalid("\(q.id): scenario needs context and steps") }
            for s in steps {
                guard s.kind != .scenario else { throw ContentError.invalid("\(s.id): nested scenario") }
                try validate(s, unique: unique, checkDiagram: checkDiagram)
            }
        }
    }

    /// Structural equality between a translation and the English master:
    /// same ids in the same order, same answers, same diagram refs.
    public static func structureMatches(_ a: StudyContent, _ b: StudyContent) -> [String] {
        var problems: [String] = []
        func sig(_ q: Question) -> String {
            "\(q.id)|\(q.kind.rawValue)|\(q.answers ?? [])|\(q.numeric.map { "\($0.value)/\($0.tolerance)/\($0.unit)" } ?? "")|\(q.options?.count ?? 0)|\(q.diagram.map { "\($0.id):\($0.variant ?? "")" } ?? "")|\((q.steps ?? []).map(sig))"
        }
        if a.modules.map(\.id) != b.modules.map(\.id) { problems.append("module ids differ") }
        for (ma, mb) in zip(a.modules, b.modules) {
            if ma.lessons.map(\.id) != mb.lessons.map(\.id) { problems.append("\(ma.id): lesson ids differ") }
            for (la, lb) in zip(ma.lessons, mb.lessons) {
                if la.segments.count != lb.segments.count { problems.append("\(la.id): segment count") }
                for (sa, sb) in zip(la.segments, lb.segments) where sa.diagram != sb.diagram {
                    problems.append("\(la.id): diagram refs differ")
                }
            }
            if ma.questions.map(sig) != mb.questions.map(sig) { problems.append("\(ma.id): question structure differs") }
        }
        if a.glossary.map(\.id) != b.glossary.map(\.id) { problems.append("glossary ids differ") }
        return problems
    }
}
