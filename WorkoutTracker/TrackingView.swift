import SwiftUI
import SwiftData
import Charts

struct TrackingView: View {
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    @Query(sort: \ExerciseSession.date, order: .reverse) var allSessions: [ExerciseSession]
    @Query var workoutDays: [WorkoutDay]
    
    var activeExercises: [Exercise] {
        allExercises.filter { !$0.sessions.isEmpty }
    }
    
    var groupedSessions: [(date: Date, sessions: [ExerciseSession])] {
        let grouped = Dictionary(grouping: allSessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        return grouped.map { (date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var totalWorkouts: Int { groupedSessions.count }
    var totalSets: Int { allSessions.reduce(0) { $0 + $1.totalSets } }
    
    func workoutTypeString(for date: Date) -> String {
        if let day = workoutDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            return day.type.rawValue
        }
        let sessions = allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if let firstEx = sessions.first?.exercise {
            return firstEx.type.rawValue
        }
        return "Workout"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if allSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard").font(.system(size: 80)).foregroundColor(.blue.opacity(0.5))
                        Text("No Workout Data Yet").font(.title2).fontWeight(.bold)
                        Text("Crush your first workout today. Your daily logs and progress charts will appear right here.")
                            .foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal, 40)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            HStack(spacing: 15) {
                                StatCard(title: "Workouts", value: "\(totalWorkouts)", icon: "flame.fill", color: .orange)
                                StatCard(title: "Total Sets", value: "\(totalSets)", icon: "number.square.fill", color: .blue)
                                StatCard(title: "Exercises", value: "\(activeExercises.count)", icon: "figure.strengthtraining.traditional", color: .purple)
                            }
                            .padding(.horizontal).padding(.top, 10)
                            
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Workout History").font(.title3).fontWeight(.bold).padding(.horizontal)
                                
                                ForEach(groupedSessions, id: \.date) { group in
                                    NavigationLink(destination: WorkoutDayDetailView(date: group.date, typeString: workoutTypeString(for: group.date))) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(group.date.formatted(.dateTime.month(.wide).day())).font(.headline).foregroundColor(.primary)
                                                Text("\(workoutTypeString(for: group.date)) Day • \(group.sessions.count) Exercises").font(.subheadline).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.4))
                                        }
                                        .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Exercise Progress").font(.title3).fontWeight(.bold).padding(.horizontal)
                                
                                ForEach(activeExercises) { exercise in
                                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(exercise.name).font(.headline).foregroundColor(.primary)
                                                Text("\(exercise.sessions.count) Sessions Logged").font(.subheadline).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chart.xyaxis.line").foregroundColor(.blue)
                                        }
                                        .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Tracking")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title2).fontWeight(.bold)
                Text(title).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

struct WorkoutDayDetailView: View {
    @Environment(\.modelContext) private var context
    let date: Date
    let typeString: String
    @Query var allSessions: [ExerciseSession]
    
    var daySessions: [ExerciseSession] {
        allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        List {
            ForEach(daySessions) { session in
                Section {
                    if let ex = session.exercise, ex.isCardio {
                        cardioRow(session: session)
                    } else {
                        strengthRow(session: session)
                    }
                    
                    if !session.notes.isEmpty {
                        Text("Notes: \(session.notes)").font(.footnote).foregroundColor(.secondary)
                    }
                } header: {
                    HStack {
                        Text(session.exercise?.name ?? "Unknown")
                        Spacer()
                        Text(session.date.formatted(date: .omitted, time: .shortened)).font(.caption).textCase(.none)
                    }
                }
            }
            .onDelete(perform: deleteSession)
        }
        .navigationTitle("\(date.formatted(.dateTime.month(.wide).day()))")
    }
    
    func cardioRow(session: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Warm-up:"); Spacer(); Text("\(session.warmUpTime ?? 0, specifier: "%.1f") min") }
            HStack { Text("Run:"); Spacer(); Text("\(session.runningTime ?? 0, specifier: "%.1f") min").bold() }
            HStack { Text("Cool-down:"); Spacer(); Text("\(session.coolDownTime ?? 0, specifier: "%.1f") min") }
            HStack { Text("Speed:"); Spacer(); Text("\(session.runningSpeed ?? 0, specifier: "%.1f")") }
            HStack { Text("Rating:"); Spacer(); Text("\(session.intensityRating ?? 0)/10").foregroundColor(.orange) }
        }.font(.subheadline)
    }
    
    func strengthRow(session: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !session.machineSettings.isEmpty {
                Text("Settings: \(session.machineSettings)").font(.caption).foregroundColor(.secondary)
            }
            let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }
            ForEach(sortedSets) { set in
                HStack {
                    Text("Set \(set.setNumber)").foregroundColor(.secondary)
                    Spacer()
                    Text("\(set.reps) reps")
                    Spacer()
                    Text("\(set.weight, specifier: "%.1f") lbs").fontWeight(.bold)
                }
            }
        }.font(.subheadline)
    }
    
    private func deleteSession(offsets: IndexSet) {
        for index in offsets { context.delete(daySessions[index]) }
        try? context.save()
    }
}
