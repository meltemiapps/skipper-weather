import Foundation

public struct StudyContent: Codable, Equatable, Sendable {
    public let language: String
    public let modules: [Module]

    public func module(id: String) -> Module? { modules.first { $0.id == id } }
    public var allLessons: [Lesson] { modules.flatMap(\.lessons) }
    public var allQuestions: [Question] { modules.flatMap(\.questions) }
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
    public let paragraphs: [String]
    public let keyPoints: [String]
    /// Optional diagram identifier rendered natively by the app.
    public let diagram: String?
}

public struct Question: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let prompt: String
    public let options: [String]
    public let answer: Int
    public let explanation: String
}

public enum ContentError: Error, Equatable {
    case invalid(String)
}

public enum ContentLoader {
    public static let knownDiagrams: Set<String> = ["buysBallot", "warmFront", "seaBreeze", "fog"]

    public static func decode(_ data: Data) throws -> StudyContent {
        let content = try JSONDecoder().decode(StudyContent.self, from: data)
        try validate(content)
        return content
    }

    /// Structural checks shared by the app (debug builds) and the unit tests.
    public static func validate(_ content: StudyContent) throws {
        var ids = Set<String>()
        func unique(_ id: String) throws {
            guard ids.insert(id).inserted else { throw ContentError.invalid("Duplicate id \(id)") }
        }
        guard !content.modules.isEmpty else { throw ContentError.invalid("No modules") }
        for m in content.modules {
            try unique(m.id)
            guard !m.lessons.isEmpty else { throw ContentError.invalid("\(m.id) has no lessons") }
            for l in m.lessons {
                try unique(l.id)
                guard !l.paragraphs.isEmpty else { throw ContentError.invalid("\(l.id) has no text") }
                if let d = l.diagram, !knownDiagrams.contains(d) {
                    throw ContentError.invalid("\(l.id) uses unknown diagram \(d)")
                }
            }
            for q in m.questions {
                try unique(q.id)
                guard q.options.count >= 2, q.options.indices.contains(q.answer) else {
                    throw ContentError.invalid("\(q.id) has an invalid answer index")
                }
                guard Set(q.options).count == q.options.count else {
                    throw ContentError.invalid("\(q.id) has duplicate options")
                }
            }
        }
    }
}
