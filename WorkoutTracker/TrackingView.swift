import SwiftUI
import SwiftData
import Charts

enum ProgressFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength"
    case cardio = "Cardio"

    var id: String { rawValue }
}

struct TrackingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    @Query(sort: \ExerciseSession.date, order: .reverse) var allSessions: [ExerciseSession]
    @Query var workoutDays: [WorkoutDay]
    
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var progressFilter: ProgressFilter = .all
    @State private var selectedChartExercise: Exercise?
    
    var activeExercises: [Exercise] {
        allExercises.filter { !$0.sessions.isEmpty }
    }

    var filteredProgressExercises: [Exercise] {
        activeExercises.filter { exercise in
            switch progressFilter {
            case .all:
                return true
            case .strength:
                return !exercise.isCardio
            case .cardio:
                return exercise.isCardio
            }
        }
    }
    
    var currentStreak: Int {
        calculateStreak()
    }
    
    var totalWorkouts: Int {
        let grouped = Dictionary(grouping: allSessions) { session in
            Calendar.current.startOfDay(for: session.date)
        }
        return grouped.count
    }

    var todaysSessions: [ExerciseSession] {
        sessionsForDate(Date())
    }

    var activatedMusclesToday: Set<TargetMuscle> {
        musclesWorked(in: todaysSessions)
    }

    /// Muscles trained in the last 3 days (excluding today) are still recovering.
    /// Muscles that weren't trained recently render with the default (gray) fill.
    var recoveringMuscles: Set<TargetMuscle> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let windowStart = calendar.date(byAdding: .day, value: -3, to: today) else { return [] }

        let recentSessions = allSessions.filter { $0.date >= windowStart && $0.date < today }
        return musclesWorked(in: recentSessions).subtracting(activatedMusclesToday)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                if allSessions.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 25) {
                            streakCard
                            todaysMuscleSection
                            calendarSection
                            progressChartSection
                            exerciseListSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Tracking")
            .navigationDestination(for: Date.self) { date in
                WorkoutSummaryView(date: date)
                    .environmentObject(themeManager)
            }
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 80))
                .foregroundColor(Color.appAccent.opacity(0.5))
            Text("No Workout Data Yet")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryText)
            Text("Crush your first workout today. Your daily logs and progress charts will appear right here.")
                .foregroundColor(themeManager.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    var streakCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("🔥 Current Streak")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryText)
                Text("\(currentStreak) days")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Workouts")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryText)
                Text("\(totalWorkouts)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appAccent)
            }
        }
        .padding()
        .appCard()
        .padding(.horizontal)
        .padding(.top, 10)
    }

    var todaysMuscleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Muscle Focus")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.primaryText)
                    Text(todaysSessions.isEmpty ? "No workout logged today" : "\(todaysSessions.count) sessions logged today")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }

                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundColor(.red)
                    .font(.title2)
            }

            MuscleDiagramView(
                activatedMuscles: activatedMusclesToday,
                restingMuscles: recoveringMuscles,
                selectedMuscles: nil,
                isEditable: false
            )
            .environmentObject(themeManager)
        }
        .padding()
        .appCard()
        .padding(.horizontal)
    }
    
    var calendarSection: some View {
        VStack(spacing: 15) {
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color.appAccent)
                        .padding(8)
                }
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryText)
                
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Color.appAccent)
                        .padding(8)
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(Array(weekdayHeaders().enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        NavigationLink(value: date) {
                            CalendarDayView(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                hasWorkout: hasWorkout(on: date),
                                hasCardio: hasCardio(on: date),
                                hasCreatine: hasCreatine(on: date),
                                isStreakDay: isPartOfStreak(date),
                                themeManager: themeManager
                            )
                        }
                        .simultaneousGesture(TapGesture().onEnded { selectedDate = date })
                    } else {
                        Text("")
                            .frame(height: 45)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .appCard()
        .padding(.horizontal)
    }
    
    /// The exercise shown in the progress chart: the user's pick if it still
    /// matches the filter, otherwise the most recently trained exercise.
    var chartExercise: Exercise? {
        if let selected = selectedChartExercise,
           filteredProgressExercises.contains(where: { $0.persistentModelID == selected.persistentModelID }) {
            return selected
        }
        return filteredProgressExercises.max {
            ($0.sessions.map(\.date).max() ?? .distantPast) < ($1.sessions.map(\.date).max() ?? .distantPast)
        }
    }

    var progressChartSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.primaryText)
                    Text(chartExercise?.isCardio == true ? "Run time per session" : "Top set weight per session")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }

                Spacer()
            }
            .padding(.horizontal)

            Picker("Progress Filter", selection: $progressFilter) {
                ForEach(ProgressFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let exercise = chartExercise {
                Menu {
                    ForEach(filteredProgressExercises) { option in
                        Button {
                            selectedChartExercise = option
                        } label: {
                            if option.persistentModelID == exercise.persistentModelID {
                                Label(option.name, systemImage: "checkmark")
                            } else {
                                Text(option.name)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundColor(themeManager.primaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                        Spacer()
                        if let best = bestValue(for: exercise) {
                            Text(exercise.isCardio
                                 ? String(format: "Best: %.1f min", best)
                                 : String(format: "Best: %.1f lbs", best))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.appAccent)
                        }
                    }
                    .padding(12)
                    .background(themeManager.inputBackground)
                    .cornerRadius(10)
                }
                .padding(.horizontal)

                let data = progressData(for: exercise)
                if data.count < 2 {
                    Text("Log this exercise a few more times to see a trend.")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                        .padding()
                } else {
                    let domain = chartDomain(for: data)
                    Chart(data) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Base", domain.lowerBound),
                            yEnd: .value("Value", point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.25), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Color.appAccent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(Color.appAccent)
                        .symbolSize(42)
                    }
                    .chartYScale(domain: domain)
                    .chartYAxisLabel(exercise.isCardio ? "Minutes" : "lbs")
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                                .foregroundStyle(themeManager.secondaryText.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(themeManager.secondaryText)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                                .foregroundStyle(themeManager.secondaryText.opacity(0.18))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .foregroundStyle(themeManager.secondaryText)
                        }
                    }
                    .frame(height: 240)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
            } else {
                Text("Complete some workouts to see progress")
                    .foregroundColor(themeManager.secondaryText)
                    .padding()
            }
        }
        .padding(.vertical)
        .appCard()
        .padding(.horizontal)
    }
    
    var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Exercise Progress")
                .appHeadingStyle()
                .foregroundColor(themeManager.primaryText)
                .padding(.horizontal)
            
            ForEach(activeExercises) { exercise in
                NavigationLink(destination: ExerciseDetailView(exercise: exercise).environmentObject(themeManager)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundColor(themeManager.primaryText)
                            if exercise.isCardio {
                                Label("Cardio", systemImage: "figure.run")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Text("\(exercise.sessions.count) Sessions Logged")
                                .font(.subheadline)
                                .foregroundColor(themeManager.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(Color.appAccent)
                    }
                    .padding()
                    .background(themeManager.secondaryBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(themeManager.cardBorder.opacity(0.8), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .appCard()
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    
    func deleteSession(_ session: ExerciseSession) {
        for set in session.sets {
            context.delete(set)
        }
        context.delete(session)
        try? context.save()
    }
    
    func changeMonth(by value: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    func weekdayHeaders() -> [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current

        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }

        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstDayWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return days
    }
    
    func hasWorkout(on date: Date) -> Bool {
        allSessions.contains { session in
            Calendar.current.isDate(session.date, inSameDayAs: date) && !(session.exercise?.isCardio ?? false)
        }
    }
    
    func hasCardio(on date: Date) -> Bool {
        allSessions.contains { session in
            Calendar.current.isDate(session.date, inSameDayAs: date) && (session.exercise?.isCardio ?? false)
        }
    }
    
    func hasCreatine(on date: Date) -> Bool {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.tookCreatine ?? false
    }
    
    func isPartOfStreak(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        guard checkDate <= today else { return false }
        
        let weekday = calendar.component(.weekday, from: checkDate)
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        return hasWorkout(on: date) || hasCardio(on: date)
    }
    
    func calculateStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Not having worked out *yet* today shouldn't reset the streak.
        if !hasWorkout(on: currentDate) && !hasCardio(on: currentDate) {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        while true {
            let didTrain = hasWorkout(on: currentDate) || hasCardio(on: currentDate)
            let weekday = calendar.component(.weekday, from: currentDate)
            let isWeekend = weekday == 1 || weekday == 7

            if didTrain {
                streak += 1
            } else if !isWeekend {
                // Weekends are rest days and don't break the streak.
                break
            }

            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }

        return streak
    }
    
    func sessionsForDate(_ date: Date) -> [ExerciseSession] {
        allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
    
    struct ProgressPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    func musclesWorked(in sessions: [ExerciseSession]) -> Set<TargetMuscle> {
        sessions.reduce(into: Set<TargetMuscle>()) { result, session in
            guard let exercise = session.exercise else { return }
            result.formUnion(exercise.targetMuscles)
        }
    }

    /// Actual values per session: top set weight for strength, run time for cardio.
    func progressData(for exercise: Exercise) -> [ProgressPoint] {
        let sortedSessions = exercise.sessions.sorted { $0.date < $1.date }

        if exercise.isCardio {
            return sortedSessions.compactMap { session in
                guard let runTime = session.runningTime, runTime > 0 else { return nil }
                return ProgressPoint(date: session.date, value: runTime)
            }
        }

        return sortedSessions.compactMap { session in
            guard let maxWeight = session.sets.map(\.weight).max(), maxWeight > 0 else { return nil }
            return ProgressPoint(date: session.date, value: maxWeight)
        }
    }

    func bestValue(for exercise: Exercise) -> Double? {
        progressData(for: exercise).map(\.value).max()
    }

    /// A y-axis window padded around the data so trends stay readable
    /// instead of being flattened against a zero baseline.
    func chartDomain(for data: [ProgressPoint]) -> ClosedRange<Double> {
        let values = data.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...1
        }
        let padding = Swift.max((maxValue - minValue) * 0.15, 5)
        return Swift.max(0, minValue - padding)...(maxValue + padding)
    }
}

struct WorkoutSummaryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \ExerciseSession.date, order: .reverse) var allSessions: [ExerciseSession]
    let date: Date

    @State private var sessionPendingDeletion: ExerciseSession?

    var sessions: [ExerciseSession] {
        allSessions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    var strengthSessions: [ExerciseSession] {
        sessions.filter { $0.exercise?.isCardio != true }
    }

    var cardioSessions: [ExerciseSession] {
        sessions.filter { $0.exercise?.isCardio == true }
    }

    var totalSets: Int {
        strengthSessions.reduce(0) { $0 + $1.sets.count }
    }

    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()

            if sessions.isEmpty {
                VStack(spacing: 15) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundColor(Color.appAccent.opacity(0.5))
                    Text("No workouts on this day")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryText)
                    Text(date.formatted(date: .long, time: .omitted))
                        .foregroundColor(themeManager.secondaryText)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(date.formatted(date: .long, time: .omitted))
                                .appHeadingStyle()
                                .foregroundColor(themeManager.primaryText)
                            Text("\(sessions.count) sessions recorded")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                        }
                        .padding(.horizontal)

                        HStack(spacing: 12) {
                            WorkoutSummaryMetric(title: "Strength", value: "\(strengthSessions.count)", icon: "dumbbell.fill", themeManager: themeManager)
                            WorkoutSummaryMetric(title: "Cardio", value: "\(cardioSessions.count)", icon: "figure.run", themeManager: themeManager)
                            WorkoutSummaryMetric(title: "Sets", value: "\(totalSets)", icon: "number", themeManager: themeManager)
                        }
                        .padding(.horizontal)

                        ForEach(sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                                    .environmentObject(themeManager)
                            } label: {
                                WorkoutSummarySessionCard(session: session, themeManager: themeManager)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    sessionPendingDeletion = session
                                } label: {
                                    Label("Delete Session", systemImage: "trash")
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text("Touch and hold a session to delete it.")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { sessionPendingDeletion != nil },
                set: { if !$0 { sessionPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete \(sessionPendingDeletion?.exercise?.name ?? "Session")", role: .destructive) {
                if let session = sessionPendingDeletion {
                    deleteSession(session)
                }
                sessionPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                sessionPendingDeletion = nil
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    private func deleteSession(_ session: ExerciseSession) {
        for set in session.sets {
            context.delete(set)
        }
        context.delete(session)
        try? context.save()
    }
}

struct WorkoutSummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color.appAccent)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryText)
            Text(title)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCard()
    }
}

struct WorkoutSummarySessionCard: View {
    let session: ExerciseSession
    let themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: session.exercise?.isCardio == true ? "figure.run.circle.fill" : "dumbbell.fill")
                .font(.title2)
                .foregroundColor(session.exercise?.isCardio == true ? .orange : Color.appAccent)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(session.exercise?.name ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                    Text(session.date.formatted(date: .omitted, time: .shortened))
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }

                HStack(spacing: 8) {
                    Text(session.location.rawValue)
                    Text(session.exercise?.isCardio == true ? cardioSummary : strengthSummary)
                }
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)

                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                        .lineLimit(2)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
                .padding(.top, 4)
        }
        .padding()
        .appCard()
    }

    private var strengthSummary: String {
        "\(session.sets.count) sets"
    }

    private var cardioSummary: String {
        if let runningTime = session.runningTime {
            return String(format: "%.1f min run", runningTime)
        }

        return "Cardio"
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasWorkout: Bool
    let hasCardio: Bool
    let hasCreatine: Bool
    let isStreakDay: Bool
    let themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : (Calendar.current.isDateInToday(date) ? Color.appAccent : themeManager.primaryText))
            
            HStack(spacing: 2) {
                if hasWorkout {
                    Circle()
                        .fill(Color.workoutDot)
                        .frame(width: 6, height: 6)
                }
                if hasCardio {
                    Circle()
                        .fill(Color.cardioDot)
                        .frame(width: 6, height: 6)
                }
                if hasCreatine {
                    Circle()
                        .fill(Color.creatineDot)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 8)
        }
        .frame(height: 45)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.appAccent : (isStreakDay ? Color.orange.opacity(0.2) : Color.clear))
        )
    }
}

struct SessionRowView: View {
    let session: ExerciseSession
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.exercise?.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryText)
                
                if let exercise = session.exercise, exercise.isCardio {
                    if let run = session.runningTime {
                        Text("\(run, specifier: "%.1f") min run")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                    }
                } else {
                    Text("\(session.sets.count) sets")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                }

                Text(session.location.rawValue)
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(themeManager.secondaryText)
        }
        .padding()
        .background(themeManager.secondaryBackground)
        .cornerRadius(12)
    }
}

struct SessionDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    let session: ExerciseSession
    
    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.exercise?.name ?? "Unknown Exercise")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryText)
                        
                        Text(session.date.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryText)

                        Label(session.location.rawValue, systemImage: session.location == .home ? "house.fill" : "figure.strengthtraining.traditional")
                            .font(.subheadline)
                            .foregroundColor(Color.appAccent)
                    }
                    .padding()
                    
                    if let exercise = session.exercise, exercise.isCardio {
                        cardioDetails
                    } else {
                        strengthDetails
                    }
                    
                    if !session.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Notes")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryText)
                            Text(session.notes)
                                .foregroundColor(themeManager.primaryText)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditSessionView(session: session).environmentObject(themeManager)) {
                    Text("Edit")
                        .foregroundColor(Color.appAccent)
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    var cardioDetails: some View {
        VStack(spacing: 15) {
            if let warmUp = session.warmUpTime {
                MetricRow(label: "Warm-up", value: "\(warmUp, default: "%.1f") min", themeManager: themeManager)
            }
            if let run = session.runningTime {
                MetricRow(label: "Run", value: "\(run, default: "%.1f") min", themeManager: themeManager)
            }
            if let coolDown = session.coolDownTime {
                MetricRow(label: "Cool-down", value: "\(coolDown, default: "%.1f") min", themeManager: themeManager)
            }
            if let speed = session.runningSpeed {
                MetricRow(label: "Speed", value: "\(speed, default: "%.1f")", themeManager: themeManager)
            }
            if let intensity = session.intensityRating {
                MetricRow(label: "Intensity", value: "\(intensity)/10", themeManager: themeManager)
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    var strengthDetails: some View {
        VStack(alignment: .leading, spacing: 15) {
            if !session.machineSettings.isEmpty {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(themeManager.secondaryText)
                    Text(session.machineSettings)
                        .foregroundColor(themeManager.primaryText)
                }
                .padding(.horizontal)
            }
            
            let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }
            
            ForEach(sortedSets) { set in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Set \(set.setNumber)")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.appAccent)
                        Spacer()
                        Text("\(set.reps) reps")
                            .foregroundColor(themeManager.primaryText)
                        Text("•")
                            .foregroundColor(themeManager.secondaryText)
                        Text("\(set.weight, specifier: "%.1f") lbs")
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryText)
                    }
                    
                    HStack {
                        DifficultyDots(rating: set.difficulty, size: 10)
                        
                        if let rest = set.restTimeSeconds {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                Text("\(rest)s rest")
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    
                    if !set.notes.isEmpty {
                        Text(set.notes)
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)
                            .italic()
                    }
                }
                .padding()
                .background(themeManager.secondaryBackground)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(themeManager.secondaryText)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)
        }
    }
}

struct EditSessionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let session: ExerciseSession
    
    @State private var machineSettings: String = ""
    @State private var sessionNotes: String = ""
    @State private var selectedLocation: WorkoutLocation = .planetFitness
    @State private var editedSets: [EditableSet] = []
    
    @State private var warmUpTime: Double? = nil
    @State private var runningTime: Double? = nil
    @State private var coolDownTime: Double? = nil
    @State private var runningSpeed: Double? = nil
    @State private var intensityRating: Double = 5.0
    
    struct EditableSet: Identifiable {
        let id: UUID
        var setNumber: Int
        var reps: Int
        var weight: Double
        var notes: String
        var difficulty: Int
        var restTimeSeconds: Int?
        var originalSet: LoggedSet?
    }
    
    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if session.exercise?.isCardio == true {
                        editCardioInterface
                    } else {
                        editStrengthInterface
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Location").font(.headline).foregroundColor(themeManager.secondaryText)
                        Picker("Workout Location", selection: $selectedLocation) {
                            ForEach(WorkoutLocation.allCases) { location in
                                Text(location.rawValue).tag(location)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Notes").font(.headline).foregroundColor(themeManager.secondaryText)
                        TextEditor(text: $sessionNotes)
                            .frame(height: 80)
                            .padding(8)
                            .background(themeManager.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(themeManager.primaryText)
                            .scrollContentBackground(.hidden)
                    }
                    
                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(15)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
        }
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .dismissableKeyboard()
        .onAppear(perform: loadSessionData)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    var editCardioInterface: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cardio Metrics").font(.headline).foregroundColor(themeManager.primaryText)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Warm-up (min)").font(.caption).foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $warmUpTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                VStack(alignment: .leading) {
                    Text("Run (min)").font(.caption).foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $runningTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cool-down (min)").font(.caption).foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $coolDownTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                VStack(alignment: .leading) {
                    Text("Speed").font(.caption).foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $runningSpeed, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Intensity").font(.headline).foregroundColor(themeManager.primaryText)
                    Spacer()
                    Text("\(Int(intensityRating))/10").fontWeight(.bold).foregroundColor(Color.appAccent)
                }
                Slider(value: $intensityRating, in: 1...10, step: 1)
                    .tint(.appAccent)
            }
            .padding()
            .background(themeManager.cardBackground)
            .cornerRadius(15)
        }
    }
    
    var editStrengthInterface: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Machine Settings").font(.headline).foregroundColor(themeManager.secondaryText)
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(themeManager.primaryText)
            }
            
            Text("Sets").font(.headline).foregroundColor(themeManager.secondaryText)
            
            ForEach($editedSets) { $set in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Set \(set.setNumber)")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.appAccent)
                        Spacer()
                        Button(action: { deleteSet(set) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Reps").font(.caption).foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.reps, format: .number)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Weight").font(.caption).foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                    }
                    
                    HStack {
                        Text("Difficulty").font(.caption).foregroundColor(themeManager.secondaryText)
                        Spacer()
                        DifficultyDots(rating: set.difficulty, size: 20, interactive: true) { newRating in
                            set.difficulty = newRating
                        }
                    }
                    
                    TextField("Set notes...", text: $set.notes)
                        .padding(10)
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                .padding()
                .background(themeManager.cardBackground)
                .cornerRadius(12)
            }
            
            Button(action: addNewSet) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Set")
                }
                .foregroundColor(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appAccent.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    func loadSessionData() {
        machineSettings = session.machineSettings
        sessionNotes = session.notes
        selectedLocation = session.location
        
        warmUpTime = session.warmUpTime
        runningTime = session.runningTime
        coolDownTime = session.coolDownTime
        runningSpeed = session.runningSpeed
        intensityRating = Double(session.intensityRating ?? 5)
        
        editedSets = session.sets.sorted { $0.setNumber < $1.setNumber }.map { set in
            EditableSet(
                id: UUID(),
                setNumber: set.setNumber,
                reps: set.reps,
                weight: set.weight,
                notes: set.notes,
                difficulty: set.difficulty,
                restTimeSeconds: set.restTimeSeconds,
                originalSet: set
            )
        }
    }
    
    func addNewSet() {
        let newSetNumber = (editedSets.map { $0.setNumber }.max() ?? 0) + 1
        editedSets.append(EditableSet(
            id: UUID(),
            setNumber: newSetNumber,
            reps: 0,
            weight: editedSets.last?.weight ?? 0,
            notes: "",
            difficulty: 3,
            restTimeSeconds: nil,
            originalSet: nil
        ))
    }
    
    func deleteSet(_ set: EditableSet) {
        editedSets.removeAll { $0.id == set.id }
        for (index, _) in editedSets.enumerated() {
            editedSets[index].setNumber = index + 1
        }
    }
    
    func saveChanges() {
        session.machineSettings = machineSettings
        session.notes = sessionNotes
        session.location = selectedLocation
        session.totalSets = editedSets.count
        
        if session.exercise?.isCardio == true {
            session.warmUpTime = warmUpTime
            session.runningTime = runningTime
            session.coolDownTime = coolDownTime
            session.runningSpeed = runningSpeed
            session.intensityRating = Int(intensityRating)
        } else {
            for oldSet in session.sets {
                context.delete(oldSet)
            }
            
            for editedSet in editedSets {
                let newSet = LoggedSet(
                    setNumber: editedSet.setNumber,
                    reps: editedSet.reps,
                    weight: editedSet.weight,
                    notes: editedSet.notes,
                    difficulty: editedSet.difficulty,
                    restTimeSeconds: editedSet.restTimeSeconds
                )
                context.insert(newSet)
                newSet.session = session
            }
        }
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("Error saving changes: \(error)")
        }
    }
}
