import SwiftUI

struct ContentView: View {
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
                
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
