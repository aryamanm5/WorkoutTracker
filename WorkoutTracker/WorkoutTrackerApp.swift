import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @State private var router = AppRouter()
    @State private var viewModel = WorkoutViewModel()
    @StateObject private var themeManager = ThemeManager()

    init() {
        do {
            container = try ModelContainer(for: WorkoutDay.self, Exercise.self, ExerciseSession.self, LoggedSet.self, BodyWeightEntry.self)
            seedInitialData(context: container.mainContext)
        } catch {
            fatalError("Failed to initialize SwiftData container.")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .environment(viewModel)
                .environmentObject(themeManager)
                .modelContainer(container)
                .onAppear {
                    viewModel.processMissingDays(context: container.mainContext)
                }
        }
    }
    
    private func seedInitialData(context: ModelContext) {
        let fetchDescriptor = FetchDescriptor<Exercise>()
        if let count = try? context.fetchCount(fetchDescriptor), count == 0 {
            let exercises = [
                // Day 1: Push
                Exercise(name: "Bench Press", type: .push),
                Exercise(name: "Shoulder Press", type: .push),
                Exercise(name: "Tricep Dips", type: .push),
                Exercise(name: "Chest Flys", type: .push),
                Exercise(name: "Lateral Raises", type: .push),
                Exercise(name: "Overhead Tricep", type: .push),
                
                // Day 2: Pull
                Exercise(name: "Pull ups", type: .pull),
                Exercise(name: "Cable Rows", type: .pull),
                Exercise(name: "Hammer Curls", type: .pull),
                Exercise(name: "Regular Curls", type: .pull),
                Exercise(name: "Rear Delt Fly", type: .pull),
                Exercise(name: "Run", type: .pull, isCardio: true),
                
                // Day 3: Legs
                Exercise(name: "Leg Press", type: .legs),
                Exercise(name: "Leg Curls", type: .legs),
                Exercise(name: "Leg Extensions", type: .legs),
                Exercise(name: "Calf Raises", type: .legs),
                Exercise(name: "Hip Abductors", type: .legs),
                Exercise(name: "Hip Adductors", type: .legs)
            ]
            for exercise in exercises {
                context.insert(exercise)
            }
            try? context.save()
        }
    }
}
