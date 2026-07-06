import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = UserDefaults.standard.integer(forKey: "initialTab")

    var body: some View {
        TabView(selection: $selectedTab) {
            CurrentWorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
                .tag(0)

            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "chart.bar.fill")
                }
                .tag(1)

            BodyWeightView()
                .tabItem {
                    Label("Body", systemImage: "scalemass.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(Color.appAccent)
        .fontDesign(themeManager.selectedFont.design)
        .preferredColorScheme(themeManager.colorScheme)
    }
}
