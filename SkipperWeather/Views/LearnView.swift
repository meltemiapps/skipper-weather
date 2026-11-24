import SwiftUI
import SkipperCore

struct LearnView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("learn.progress")).font(.headline)
                        ProgressView(value: model.progress).tint(Palette.accent)
                        Text(t.format("learn.completeOf", model.completedCount, model.content.allLessons.count))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .glassCard()

                    if let next = model.nextLesson {
                        NavigationLink(value: Route.lesson(next.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill").font(.title3).foregroundStyle(Palette.amber)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("learn.continue")).font(.caption.weight(.semibold)).foregroundStyle(Palette.amber)
                                    Text(next.title).font(.headline).multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                            }
                            .glassCard(tint: Palette.amber)
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        GlossaryView()
                    } label: {
                        Label(t("learn.glossary"), systemImage: "character.book.closed")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                    }
                    .buttonStyle(.plain)

                    Text(t("learn.modules")).font(.title3.bold()).padding(.top, 6)

                    ForEach(model.content.modules) { module in
                        NavigationLink(value: Route.module(module.id)) {
                            ModuleRow(module: module)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("module.\(module.id)")
                    }
                }
                .padding()
            }
            .screen()
            .navigationTitle(t("tab.learn"))
            .navigationDestination(for: Route.self) { RouteDestination(route: $0) }
        }
    }
}

struct ModuleRow: View {
    @Environment(AppModel.self) private var model
    let module: Module

    var body: some View {
        let done = module.lessons.filter { model.isComplete($0.id) }.count
        HStack(spacing: 14) {
            Image(systemName: module.symbol)
                .font(.title2)
                .frame(width: 44, height: 44)
                .foregroundStyle(Palette.accent)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(module.title).font(.headline)
                Text(module.summary).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text("\(done)/\(module.lessons.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(done == module.lessons.count ? Palette.good : .secondary)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

struct ModuleView: View {
    @Environment(AppModel.self) private var model
    let moduleID: String

    var body: some View {
        let t = model.strings
        if let module = model.content.module(id: moduleID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(module.summary).foregroundStyle(.secondary)
                    ForEach(module.lessons) { lesson in
                        NavigationLink(value: Route.lesson(lesson.id)) {
                            HStack {
                                Image(systemName: model.isComplete(lesson.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.isComplete(lesson.id) ? Palette.good : .secondary)
                                Text(lesson.title).font(.headline).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").foregroundStyle(.secondary)
                            }
                            .glassCard()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("lesson.\(lesson.id)")
                    }
                    NavigationLink(value: Route.quiz(module.id)) {
                        Label(t("quiz.start"), systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .foregroundStyle(Palette.onAccent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding()
            }
            .screen()
            .navigationTitle(module.title)
        }
    }
}

struct LessonView: View {
    @Environment(AppModel.self) private var model
    let lessonID: String

    var body: some View {
        let t = model.strings
        if let lesson = model.lesson(id: lessonID) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if model.contentIsFallback {
                        Label(t("lesson.englishOnly"), systemImage: "globe")
                            .font(.footnote)
                            .glassCard(cornerRadius: 16, tint: Palette.amber)
                    }

                    ForEach(Array(lesson.segments.enumerated()), id: \.offset) { _, segment in
                        SegmentView(segment: segment)
                    }

                    Button {
                        model.setComplete(lesson.id, !model.isComplete(lesson.id))
                    } label: {
                        Label(model.isComplete(lesson.id) ? t("lesson.completed") : t("lesson.markComplete"),
                              systemImage: model.isComplete(lesson.id) ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .foregroundStyle(Palette.onAccent)
                    .controlSize(.large)
                    .sensoryFeedback(.success, trigger: model.isComplete(lesson.id))
                    .accessibilityIdentifier("lesson.complete")
                }
                .padding()
            }
            .screen()
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SegmentView: View {
    @Environment(AppModel.self) private var model
    let segment: Segment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(segment.heading)
                .font(.title3.bold())
                .fixedSize(horizontal: false, vertical: true)
            if let d = segment.diagram {
                DiagramView(ref: d)
                    .glassCard()
            }
            ForEach(Array(segment.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let points = segment.keyPoints, !points.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.strings("lesson.keyPoints"))
                        .font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(Palette.accent)
                    ForEach(points, id: \.self) { point in
                        Label {
                            Text(point).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "checkmark").foregroundStyle(Palette.good)
                        }
                    }
                }
                .glassCard(tint: Palette.accent)
            }
        }
    }
}

struct GlossaryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    var body: some View {
        let entries = model.content.glossary.filter {
            query.isEmpty || $0.term.localizedCaseInsensitiveContains(query) || $0.definition.localizedCaseInsensitiveContains(query)
        }
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.term).font(.headline)
                Text(entry.definition).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .background(SeaBackground())
        .searchable(text: $query)
        .navigationTitle(model.strings("learn.glossary"))
    }
}
