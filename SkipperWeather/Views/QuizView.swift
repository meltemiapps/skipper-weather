import SwiftUI
import SkipperCore

struct QuizHomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink { MockExamView() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "timer").font(.title2).foregroundStyle(Palette.amber).frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("quiz.mock")).font(.headline)
                                Text(t.format("quiz.mockIntro", MockExam.questionCount, MockExam.durationMinutes, Int(MockExam.passMark * 100)))
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if let best = model.bestScores["mock"] { scoreBadge(best) }
                            Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                        }
                        .glassCard(tint: Palette.amber)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quiz.mock")

                    scopeRow(scope: "all", title: t("quiz.allModules"), symbol: "square.grid.2x2")
                    ForEach(model.content.modules) { module in
                        scopeRow(scope: module.id, title: module.title, symbol: module.symbol)
                    }
                }
                .padding()
            }
            .screen()
            .navigationTitle(t("tab.quiz"))
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
        }
    }

    private func scoreBadge(_ best: Int) -> some View {
        Text("\(best)%")
            .font(.subheadline.monospacedDigit().weight(.semibold))
            .foregroundStyle(best >= 70 ? Palette.good : Palette.amber)
            .accessibilityLabel("\(model.strings("quiz.best")) \(best)%")
    }

    private func scopeRow(scope: String, title: String, symbol: String) -> some View {
        NavigationLink(value: Route.quiz(scope)) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Palette.accent).frame(width: 32)
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if let best = model.bestScores[scope] { scoreBadge(best) }
                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quiz.scope.\(scope)")
    }
}

/// Module or mixed practice quiz.
struct QuizRunView: View {
    @Environment(AppModel.self) private var model
    let scope: String
    @State private var session: QuizSession?

    var body: some View {
        let t = model.strings
        Group {
            if let session {
                QuizRunner(session: Binding(get: { self.session ?? session }, set: { self.session = $0 }), scope: scope, onRestart: restart)
            } else {
                // An empty Group has no view to attach onAppear to, so the session would never start.
                Color.clear
            }
        }
        .screen()
        .navigationTitle(scope == "all" ? t("quiz.allModules") : (model.content.module(id: scope)?.title ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if session == nil { restart() } }
        .onChange(of: model.effectiveLanguage) { _, _ in restart() }
    }

    private func restart() {
        var rng = SystemRandomNumberGenerator()
        let pool = scope == "all" ? model.content.allQuestions : (model.content.module(id: scope)?.questions ?? [])
        session = QuizSession(questions: pool, limit: scope == "all" ? 12 : pool.count, using: &rng)
    }
}

/// Shared question flow used by practice quizzes and the mock exam.
struct QuizRunner: View {
    @Environment(AppModel.self) private var model
    @Binding var session: QuizSession
    let scope: String
    var timeUp = false
    let onRestart: () -> Void
    @State private var recorded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if session.phase == .finished || timeUp {
                    QuizResults(session: session, scope: scope, onRestart: onRestart)
                        .onAppear(perform: record)
                } else if let item = session.current {
                    QuestionCard(item: item, index: session.index, total: session.total, phase: session.phase,
                                 isLast: session.isLast, isCorrect: session.lastAnswerCorrect,
                                 respond: { session.respond($0) },
                                 hasResponse: session.response != nil,
                                 check: { session.check() }, next: { session.next() })
                        .id(session.index)
                }
            }
            .padding()
        }
    }

    private func record() {
        guard !recorded else { return }
        recorded = true
        model.recordScore(Int((session.score * 100).rounded()), scope: scope)
    }
}

struct QuestionCard: View {
    @Environment(AppModel.self) private var model
    let item: QuizItem
    let index: Int
    let total: Int
    let phase: QuizSession.Phase
    let isLast: Bool
    let isCorrect: Bool?
    let respond: (Response) -> Void
    let hasResponse: Bool
    let check: () -> Void
    let next: () -> Void

    @State private var multi: Set<Int> = []
    @State private var single: Int?
    @State private var order: [Int] = []
    @State private var numberText = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var q: Question { item.question }
    private var checked: Bool { phase == .checked }

    var body: some View {
        let t = model.strings
        VStack(alignment: .leading, spacing: 14) {
            Text(t.format("quiz.questionOf", index + 1, total))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ProgressView(value: Double(index), total: Double(max(total, 1))).tint(Palette.accent)

            if let scenario = item.scenario {
                VStack(alignment: .leading, spacing: 6) {
                    Label(t("quiz.scenario"), systemImage: "sailboat").font(.caption.weight(.bold)).foregroundStyle(Palette.amber)
                    Text(scenario.context ?? "").font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if let n = item.stepNumber, let c = item.stepCount {
                        Text(t.format("quiz.step", n, c)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .glassCard(tint: Palette.amber)
            } else if let context = q.context {
                Text(context).font(.subheadline).fixedSize(horizontal: false, vertical: true).glassCard(tint: Palette.amber)
            }

            if let d = q.diagram ?? item.scenario?.diagram {
                DiagramView(ref: d, height: 200).glassCard()
            }

            Text(q.prompt).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)

            answerArea

            if checked, let correct = isCorrect {
                VStack(alignment: .leading, spacing: 6) {
                    Text(correct ? t("quiz.correct") : t("quiz.incorrect"))
                        .font(.headline).foregroundStyle(correct ? Palette.good : Palette.amber)
                    if !correct, let answer = correctAnswerText {
                        Text("\(t("quiz.correctAnswer")): \(answer)").font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(q.explanation).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .glassCard()
                .sensoryFeedback(correct ? .success : .error, trigger: index)
            }

            Button {
                if checked { next() } else { check() }
            } label: {
                Text(checked ? (isLast ? t("quiz.finish") : t("quiz.next")) : t("quiz.check")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .foregroundStyle(Palette.onAccent)
            .controlSize(.large)
            .disabled(!checked && !hasResponse)
            .accessibilityIdentifier("quiz.action")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("question.\(item.scenario != nil ? "scenario" : q.kind.rawValue)")
        .onAppear(perform: prepare)
    }

    private func prepare() {
        if q.kind == .order, order.isEmpty, let opts = q.options {
            var o = Array(opts.indices)
            repeat { o.shuffle() } while o == (q.answers ?? []) && o.count > 1
            order = o
            respond(.order(o))
        }
    }

    @ViewBuilder
    private var answerArea: some View {
        let t = model.strings
        let options = q.options ?? []
        switch q.kind {
        case .single, .multi:
            if q.kind == .multi {
                Text(t("quiz.selectAll")).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                Button {
                    guard !checked else { return }
                    if q.kind == .multi {
                        if multi.contains(i) { multi.remove(i) } else { multi.insert(i) }
                        respond(.choices(multi.sorted()))
                    } else {
                        single = i
                        respond(.choices([i]))
                    }
                } label: {
                    optionLabel(i, option)
                }
                .buttonStyle(.plain)
                .disabled(checked)
                .accessibilityAddTraits(isSelected(i) ? .isSelected : [])
                .accessibilityIdentifier("quiz.option.\(i)")
            }
        case .numeric:
            HStack {
                TextField(t("quiz.enterValue"), text: $numberText)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.title2.monospacedDigit())
                    .disabled(checked)
                    .accessibilityIdentifier("quiz.number")
                    .onChange(of: numberText) { _, text in
                        if let v = parse(text) { respond(.number(v)) }
                    }
                Text(q.numeric?.unit ?? "").font(.title3).foregroundStyle(.secondary)
            }
            .glassCard(cornerRadius: 18)
        case .order:
            Text(t("quiz.orderHint")).font(.caption).foregroundStyle(.secondary)
            ForEach(Array(order.enumerated()), id: \.element) { pos, optionIndex in
                // At accessibility text sizes the arrows go under the text so it keeps the full width.
                let stacked = dynamicTypeSize.isAccessibilitySize
                let row = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
                row {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(pos + 1)").font(.headline.monospacedDigit()).frame(minWidth: 24)
                        Text(options[optionIndex]).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        if !checked {
                            Button { move(pos, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(pos == 0)
                            Button { move(pos, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(pos == order.count - 1)
                        } else if let answers = q.answers {
                            Image(systemName: answers[pos] == optionIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(answers[pos] == optionIndex ? Palette.good : Palette.bad)
                        }
                    }
                    .frame(maxWidth: stacked ? .infinity : nil, alignment: .trailing)
                }
                .buttonStyle(.glass)
                .glassCard(cornerRadius: 16)
            }
        case .scenario:
            EmptyView()
        }
    }

    private func optionLabel(_ i: Int, _ option: String) -> some View {
        let answers = Set(q.answers ?? [])
        let tint: Color? = checked ? (answers.contains(i) ? Palette.good : (isSelected(i) ? Palette.bad : nil)) : (isSelected(i) ? Palette.accent : nil)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if q.kind == .multi {
                    Image(systemName: isSelected(i) ? "checkmark.square.fill" : "square").foregroundStyle(Palette.accent)
                }
                Text(option).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if checked && answers.contains(i) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good)
                } else if checked && isSelected(i) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.bad)
                }
            }
            if checked, let why = q.optionExplanations?[i], answers.contains(i) || isSelected(i) {
                Text(why).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .glassCard(cornerRadius: 18, tint: tint)
    }

    private func isSelected(_ i: Int) -> Bool { q.kind == .multi ? multi.contains(i) : single == i }

    private func move(_ pos: Int, by delta: Int) {
        let target = pos + delta
        guard order.indices.contains(target) else { return }
        order.swapAt(pos, target)
        respond(.order(order))
    }

    private func parse(_ text: String) -> Double? {
        let f = NumberFormatter()
        f.locale = model.locale
        f.numberStyle = .decimal
        if let n = f.number(from: text.trimmingCharacters(in: .whitespaces)) { return n.doubleValue }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private var correctAnswerText: String? {
        let options = q.options ?? []
        switch q.kind {
        case .single, .multi: return (q.answers ?? []).map { options[$0] }.joined(separator: ", ")
        case .order: return (q.answers ?? []).map { options[$0] }.joined(separator: " → ")
        case .numeric:
            guard let n = q.numeric else { return nil }
            let v = model.number(n.value, digits: 2)
            return n.tolerance > 0 ? "\(v) \(n.unit) ± \(model.number(n.tolerance, digits: 2))" : "\(v) \(n.unit)"
        case .scenario: return nil
        }
    }
}

struct QuizResults: View {
    @Environment(AppModel.self) private var model
    let session: QuizSession
    let scope: String
    let onRestart: () -> Void

    var body: some View {
        let t = model.strings
        let percent = Int((session.score * 100).rounded())
        let passed = MockExam.passed(score: session.score)
        VStack(spacing: 12) {
            Image(systemName: passed ? "trophy.fill" : "sailboat.fill")
                .font(.system(size: 48)).foregroundStyle(passed ? Palette.amber : Palette.accent)
            if scope == "mock" {
                Text(passed ? t("quiz.passed") : t("quiz.failed")).font(.title.bold())
                    .foregroundStyle(passed ? Palette.good : Palette.amber)
            }
            Text(t.format("quiz.result", session.correctCount, session.total)).font(.title2.bold())
            Text("\(percent)%").font(.largeTitle.monospacedDigit().weight(.heavy))
            if let best = model.bestScores[scope] {
                Text("\(t("quiz.best")): \(best)%").foregroundStyle(.secondary)
            }
            if !session.missed.isEmpty {
                DisclosureGroup(t("quiz.review")) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(missedItems, id: \.question.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.question.prompt).font(.subheadline.weight(.semibold))
                                Text(item.question.explanation).font(.footnote).foregroundStyle(.secondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 8)
                }
                .tint(Palette.accent)
            }
            Button(t("quiz.again"), action: onRestart)
                .buttonStyle(.glassProminent)
                .foregroundStyle(Palette.onAccent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var missedItems: [QuizItem] { session.items.filter { session.missed.contains($0.question.id) } }
}

struct MockExamView: View {
    @Environment(AppModel.self) private var model
    @State private var session: QuizSession?
    @State private var endsAt: Date?
    @State private var timeUp = false

    var body: some View {
        let t = model.strings
        Group {
            if let session, let endsAt {
                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(endsAt.timeIntervalSince(context.date)))
                        HStack {
                            Label(t("quiz.timeLeft"), systemImage: "timer")
                            Spacer()
                            Text(String(format: "%02d:%02d", remaining / 60, remaining % 60)).monospacedDigit()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(remaining < 300 ? Palette.amber : .primary)
                        .padding(.horizontal).padding(.vertical, 8)
                        .onChange(of: remaining) { _, r in if r == 0 { timeUp = true } }
                    }
                    QuizRunner(session: Binding(get: { self.session ?? session }, set: { self.session = $0 }), scope: "mock", timeUp: timeUp, onRestart: start)
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "timer").font(.system(size: 48)).foregroundStyle(Palette.amber)
                        Text(t("quiz.mock")).font(.title.bold())
                        Text(t.format("quiz.mockIntro", MockExam.questionCount, MockExam.durationMinutes, Int(MockExam.passMark * 100)))
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        Button(t("quiz.start"), action: start)
                            .buttonStyle(.glassProminent).foregroundStyle(Palette.onAccent).controlSize(.large)
                            .accessibilityIdentifier("mock.start")
                    }
                    .frame(maxWidth: .infinity)
                    .glassCard()
                    .padding()
                }
            }
        }
        .screen()
        .navigationTitle(t("quiz.mock"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start() {
        var rng = SystemRandomNumberGenerator()
        session = QuizSession(questions: MockExam.make(from: model.content, using: &rng))
        endsAt = Date().addingTimeInterval(TimeInterval(MockExam.durationMinutes * 60))
        timeUp = false
    }
}
