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
            container = try ModelContainer(for: WorkoutDay.self, Exercise.self, ExerciseSession.self, LoggedSet.self, BodyWeightEntry.self, ProgressPhoto.self)
            seedInitialData(context: container.mainContext)
            mergeDuplicateExercises(context: container.mainContext)
            migrateMuscleTargetsIfNeeded(context: container.mainContext)
            #if DEBUG
            seedDemoDataIfRequested(context: container.mainContext)
            #endif
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
    
    #if DEBUG
    /// Seeds sample sessions when launched with `-demoSeed 1` so screens with
    /// history (tracking, charts, calendar) can be exercised in the simulator.
    private func seedDemoDataIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "demoSeed") else { return }
        let sessionCount = (try? context.fetchCount(FetchDescriptor<ExerciseSession>())) ?? 0
        guard sessionCount == 0,
              let exercises = try? context.fetch(FetchDescriptor<Exercise>()) else { return }

        let calendar = Calendar.current
        for (index, exercise) in exercises.prefix(8).enumerated() {
            // Leave the last two exercises untrained today so the
            // "recovering" state is visible on the muscle map.
            let schedule = index >= 6 ? [2, 4, 7, 9, 14] : [0, 2, 4, 7, 9, 14]
            for (sessionIndex, daysAgo) in schedule.enumerated() {
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
                    .addingTimeInterval(Double(index) * 600)
                let session = ExerciseSession(date: date, machineSettings: "Seat 4", totalSets: 3)
                context.insert(session)
                session.exercise = exercise

                if exercise.isCardio {
                    session.runningTime = 25 - Double(sessionIndex)
                    session.runningSpeed = 6.2
                    session.intensityRating = 6
                } else {
                    let base = 80.0 + Double(index) * 15
                    for setNumber in 1...3 {
                        let set = LoggedSet(
                            setNumber: setNumber,
                            reps: 10,
                            weight: base - Double(sessionIndex) * 5,
                            difficulty: min(5, setNumber + 1),
                            restTimeSeconds: setNumber > 1 ? 90 : nil
                        )
                        context.insert(set)
                        set.session = session
                    }
                }
            }
        }

        for daysAgo in 0..<12 {
            let entry = BodyWeightEntry(
                date: calendar.date(byAdding: .day, value: -daysAgo, to: Date())!,
                weight: 178 + Double(daysAgo) * 0.4
            )
            context.insert(entry)
        }
        try? context.save()
    }
    #endif

    /// Earlier CSV imports created a duplicate Exercise per imported row.
    /// Merge exercises that share a name (case-insensitive) into one,
    /// moving their sessions over before deleting the extras.
    private func mergeDuplicateExercises(context: ModelContext) {
        guard let exercises = try? context.fetch(FetchDescriptor<Exercise>()) else { return }

        var keepers: [String: Exercise] = [:]
        var duplicates: [Exercise] = []

        for exercise in exercises.sorted(by: { $0.sessions.count > $1.sessions.count }) {
            let key = exercise.name.lowercased()
            if let keeper = keepers[key] {
                for session in exercise.sessions {
                    session.exercise = keeper
                }
                duplicates.append(exercise)
            } else {
                keepers[key] = exercise
            }
        }

        guard !duplicates.isEmpty else { return }
        for duplicate in duplicates {
            context.delete(duplicate)
        }
        try? context.save()
    }

    /// Muscle targets saved before the catalog fix contain incorrect defaults
    /// (e.g. "Rear Delt Fly" tagged as chest). Recompute them once.
    private func migrateMuscleTargetsIfNeeded(context: ModelContext) {
        let migrationKey = "didMigrateMuscleTargets_v2"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if let exercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in exercises {
                exercise.targetMuscles = MuscleCatalog.defaultTargets(
                    for: exercise.name,
                    type: exercise.type,
                    isCardio: exercise.isCardio
                )
            }
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
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
