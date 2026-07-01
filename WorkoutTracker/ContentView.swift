import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        TabView {
            CurrentWorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "figure.strengthtraining.traditional")
                }
            
            TrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "chart.bar.fill")
                }
            
            BodyWeightView()
                .tabItem {
                    Label("Body", systemImage: "scalemass.fill")
                }
                
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(Color.appAccent)
        .font(themeManager.selectedFont.font)
        .preferredColorScheme(themeManager.colorScheme)
    }
}
