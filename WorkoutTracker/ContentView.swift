import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "initialTab")

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(0)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            BodyWeightView()
                .tabItem {
                    Label("Body", systemImage: "figure.arms.open")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        // Rebuild the whole tree when the theme changes so every cached
        // `Color.app*` provider re-resolves against the new palette instantly.
        .id(themeManager.theme)
        .tint(Color.appAccent)
        .fontDesign(themeManager.selectedFont.design)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

/// Sheets and full-screen covers are separate presentations, so the root
/// font design and color scheme don't reach them — reapply on presentation.
struct ThemedPresentation: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager

    func body(content: Content) -> some View {
        content
            .fontDesign(themeManager.selectedFont.design)
            .preferredColorScheme(themeManager.colorScheme)
    }
}

extension View {
    func themedPresentation() -> some View {
        modifier(ThemedPresentation())
    }
}
