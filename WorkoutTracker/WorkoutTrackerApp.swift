import SwiftUI
import SwiftData

@main
struct WorkoutTrackerApp: App {
    let container: ModelContainer
    @StateObject private var themeManager = ThemeManager()

    init() {
        do {
            container = try ModelContainer(for: WorkoutDay.self, Exercise.self, ExerciseSession.self, LoggedSet.self, BodyWeightEntry.self, ProgressPhoto.self)
            #if DEBUG
            resetDataIfRequested(context: container.mainContext)
            #endif
            seedInitialData(context: container.mainContext)
            #if DEBUG
            seedDemoDataIfRequested(context: container.mainContext)
            #endif
        } catch {
            fatalError("Failed to initialize SwiftData container.")
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .modelContainer(container)
                .onAppear {
                    Haptics.shared.prepare()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // iOS shuts the haptic engine down while we're backgrounded, so the
            // first tap after returning would otherwise be silent.
            if phase == .active { Haptics.shared.prepare() }
        }
    }
    
    #if DEBUG
    /// Wipes the store when launched with `-resetData 1` so UI tests always
    /// start from a known state regardless of what earlier runs logged.
    private func resetDataIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "resetData") else { return }
        try? context.delete(model: LoggedSet.self)
        try? context.delete(model: ExerciseSession.self)
        try? context.delete(model: Exercise.self)
        try? context.delete(model: WorkoutDay.self)
        try? context.delete(model: BodyWeightEntry.self)
        try? context.delete(model: ProgressPhoto.self)
        try? context.save()
    }

    /// Seeds sample sessions when launched with `-demoSeed 1` so screens with
    /// history (tracking, charts, calendar) can be exercised in the simulator.
    private func seedDemoDataIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "demoSeed") else { return }
        let sessionCount = (try? context.fetchCount(FetchDescriptor<ExerciseSession>())) ?? 0
        guard sessionCount == 0,
              let exercises = try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)])) else { return }

        let calendar = Calendar.current
        for (index, exercise) in exercises.prefix(8).enumerated() {
            // Leave the last two exercises untrained today so the
            // "recovering" state is visible on the muscle map.
            let schedule = index >= 6 ? [2, 4, 7, 9, 14] : [0, 2, 4, 7, 9, 14]
            for (sessionIndex, daysAgo) in schedule.enumerated() {
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
                    .addingTimeInterval(Double(index) * 600)
                let session = ExerciseSession(date: date, machineSettings: "Seat 4", totalSets: 3, location: exercise.location)
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
                Exercise(name: "Hip Adductors", type: .legs),

                // Home library (separate from the gym's)
                Exercise(name: "Push Ups", type: .push, location: .home),
                Exercise(name: "Dumbbell Shoulder Press", type: .push, location: .home),
                Exercise(name: "Dumbbell Rows", type: .pull, location: .home),
                Exercise(name: "Dumbbell Curls", type: .pull, location: .home),
                Exercise(name: "Goblet Squats", type: .legs, location: .home),
                Exercise(name: "Lunges", type: .legs, location: .home)
            ]
            for exercise in exercises {
                context.insert(exercise)
            }
            try? context.save()
        }
    }
}
