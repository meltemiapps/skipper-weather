import SwiftUI
import SkipperCore

struct QuizHomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
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

    private func scopeRow(scope: String, title: String, symbol: String) -> some View {
        NavigationLink(value: Route.quiz(scope)) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.title3).foregroundStyle(Palette.accent).frame(width: 32)
                Text(title).font(.headline).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if let best = model.bestScores[scope] {
                    Text("\(best)%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(best >= 80 ? Palette.good : Palette.amber)
                        .accessibilityLabel("\(model.strings("quiz.best")) \(best)%")
                }
                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}

struct QuizRunView: View {
    @Environment(AppModel.self) private var model
    let scope: String
    @State private var session: QuizSession?
    @State private var recorded = false

    var body: some View {
        let t = model.strings
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let session {
                    switch session.phase {
                    case .finished: results(session)
                    default: questionCard(session)
                    }
                }
            }
            .padding()
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
        session = QuizSession(questions: pool, limit: scope == "all" ? 10 : pool.count, using: &rng)
        recorded = false
    }

    @ViewBuilder
    private func questionCard(_ s: QuizSession) -> some View {
        let t = model.strings
        if let q = s.current {
            Text(t.format("quiz.questionOf", s.index + 1, s.questions.count))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ProgressView(value: Double(s.index), total: Double(max(s.questions.count, 1))).tint(Palette.accent)
            Text(q.prompt).font(.title3.weight(.semibold)).padding(.vertical, 4)

            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                Button { session?.select(i) } label: {
                    HStack {
                        Text(option).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        if s.phase == .checked && i == q.answer {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.good)
                        } else if s.phase == .checked && i == s.selected {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.bad)
                        }
                    }
                    .glassCard(cornerRadius: 18, tint: tint(for: i, in: s, question: q))
                }
                .buttonStyle(.plain)
                .disabled(s.phase != .answering)
                .accessibilityAddTraits(s.selected == i ? .isSelected : [])
            }

            if s.phase == .checked, let correct = s.lastAnswerCorrect {
                VStack(alignment: .leading, spacing: 6) {
                    Text(correct ? t("quiz.correct") : t("quiz.incorrect"))
                        .font(.headline).foregroundStyle(correct ? Palette.good : Palette.amber)
                    Text(q.explanation).font(.subheadline)
                }
                .glassCard()
                .sensoryFeedback(correct ? .success : .error, trigger: s.index)
            }

            Button {
                if s.phase == .answering { session?.check() } else { session?.next() }
            } label: {
                Text(s.phase == .answering ? t("quiz.check") : (s.isLast ? t("quiz.finish") : t("quiz.next")))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(s.phase == .answering && s.selected == nil)
            .padding(.top, 4)
        }
    }

    private func tint(for i: Int, in s: QuizSession, question q: Question) -> Color? {
        switch s.phase {
        case .answering: return s.selected == i ? Palette.accent : nil
        case .checked:
            if i == q.answer { return Palette.good }
            return i == s.selected ? Palette.bad : nil
        case .finished: return nil
        }
    }

    @ViewBuilder
    private func results(_ s: QuizSession) -> some View {
        let t = model.strings
        let percent = Int((s.score * 100).rounded())
        VStack(spacing: 12) {
            Image(systemName: percent >= 80 ? "trophy.fill" : "sailboat.fill")
                .font(.system(size: 48)).foregroundStyle(percent >= 80 ? Palette.amber : Palette.accent)
            Text(t.format("quiz.result", s.correctCount, s.questions.count)).font(.title2.bold())
            Text("\(percent)%").font(.largeTitle.monospacedDigit().weight(.heavy))
            if let best = model.bestScores[scope] {
                Text("\(t("quiz.best")): \(best)%").foregroundStyle(.secondary)
            }
            Button(t("quiz.again")) { restart() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
        .onAppear {
            if !recorded { model.recordScore(percent, scope: scope); recorded = true }
        }
    }
}
