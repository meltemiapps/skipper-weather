import SwiftUI

enum Route: Hashable {
    case module(String)
    case lesson(String)
    case quiz(String)
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let t = model.strings
        TabView {
            Tab(t("tab.learn"), systemImage: "book.pages") { LearnView() }
            Tab(t("tab.quiz"), systemImage: "checkmark.seal") { QuizHomeView() }
            Tab(t("tab.tools"), systemImage: "gauge.with.dots.needle.33percent") { ToolsView() }
            Tab(t("tab.settings"), systemImage: "gearshape") { SettingsView() }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .environment(\.locale, model.locale)
        .environment(\.layoutDirection, model.layoutDirection)
    }
}

/// Shared destination resolver so every tab can push lessons and quizzes.
struct RouteDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .module(let id): ModuleView(moduleID: id)
        case .lesson(let id): LessonView(lessonID: id)
        case .quiz(let scope): QuizRunView(scope: scope)
        }
    }
}
