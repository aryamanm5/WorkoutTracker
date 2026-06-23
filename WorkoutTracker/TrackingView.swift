import SwiftUI
import SwiftData
import Charts

struct TrackingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) var allExercises: [Exercise]
    @Query(sort: \ExerciseSession.date, order: .reverse) var allSessions: [ExerciseSession]
    @Query var workoutDays: [WorkoutDay]
    
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    
    var activeExercises: [Exercise] {
        allExercises.filter { !$0.sessions.isEmpty && !$0.isCardio }
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
                            calendarSection
                            selectedDaySection
                            progressChartSection
                            exerciseListSection
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Tracking")
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
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
                Text("\(currentStreak) days")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Workouts")
                    .appBodyStyle()
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
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .appCaptionStyle()
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        CalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            hasWorkout: hasWorkout(on: date),
                            hasCardio: hasCardio(on: date),
                            hasCreatine: hasCreatine(on: date),
                            isStreakDay: isPartOfStreak(date),
                            themeManager: themeManager
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
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
    
    var selectedDaySection: some View {
        let sessions = sessionsForDate(selectedDate)
        
        return VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .appHeadingStyle()
                    .foregroundColor(themeManager.primaryText)
                
                Spacer()
                
                if !sessions.isEmpty {
                    Text("Swipe to delete")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .padding(.horizontal)
            
            if sessions.isEmpty {
                Text("No workouts on this day")
                    .foregroundColor(themeManager.secondaryText)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                                .environmentObject(themeManager)
                        } label: {
                            SessionRowView(
                                session: session,
                                themeManager: themeManager
                            )
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteSession(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: CGFloat(max(sessions.count, 1)) * 90)
            }
        }
        .padding(.vertical)
        .appCard()
        .padding(.horizontal)
    }
    
    var progressChartSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Progress Overview")
                .appHeadingStyle()
                .foregroundColor(themeManager.primaryText)
                .padding(.horizontal)
            
            if activeExercises.isEmpty {
                Text("Complete some strength workouts to see progress")
                    .foregroundColor(themeManager.secondaryText)
                    .padding()
            } else {
                Chart {
                    ForEach(activeExercises) { exercise in
                        ForEach(normalizedProgressData(for: exercise)) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Progress", point.normalizedValue)
                            )
                            .foregroundStyle(by: .value("Exercise", exercise.name))
                        }
                    }
                }
                .chartYAxisLabel("Relative Improvement %")
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 250)
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
                                .appHeadingStyle()
                                .foregroundColor(themeManager.primaryText)
                            Text("\(exercise.sessions.count) Sessions Logged")
                                .appBodyStyle()
                                .foregroundColor(themeManager.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(Color.appAccent)
                    }
                    .padding()
                    .background(themeManager.secondaryBackground)
                    .cornerRadius(12)
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
    
    func daysInMonth() -> [Date?] {
        let calendar = Calendar.current
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)
        for _ in 1..<firstDayWeekday {
            days.append(nil)
        }
        
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
        
        while true {
            let weekday = calendar.component(.weekday, from: currentDate)
            
            if weekday == 1 || weekday == 7 {
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                continue
            }
            
            if hasWorkout(on: currentDate) || hasCardio(on: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
            } else {
                break
            }
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
        let normalizedValue: Double
    }
    
    func normalizedProgressData(for exercise: Exercise) -> [ProgressPoint] {
        let sortedSessions = exercise.sessions.sorted { $0.date < $1.date }
        guard let firstSession = sortedSessions.first,
              let firstMaxWeight = firstSession.sets.map({ $0.weight }).max(),
              firstMaxWeight > 0 else {
            return []
        }
        
        return sortedSessions.compactMap { session in
            guard let maxWeight = session.sets.map({ $0.weight }).max() else { return nil }
            let normalizedValue = ((maxWeight - firstMaxWeight) / firstMaxWeight) * 100
            return ProgressPoint(date: session.date, normalizedValue: normalizedValue)
        }
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
                    .appHeadingStyle()
                    .foregroundColor(themeManager.primaryText)
                
                if let exercise = session.exercise, exercise.isCardio {
                    if let run = session.runningTime {
                        Text("\(run, specifier: "%.1f") min run")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                } else {
                    Text("\(session.sets.count) sets")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
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
                            .appLargeTitleStyle()
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.primaryText)
                        
                        Text(session.date.formatted(date: .long, time: .shortened))
                            .appBodyStyle()
                            .foregroundColor(themeManager.secondaryText)
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
                                .appHeadingStyle()
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
                                    .appCaptionStyle()
                                Text("\(rest)s rest")
                                    .appCaptionStyle()
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    
                    if !set.notes.isEmpty {
                        Text(set.notes)
                            .appCaptionStyle()
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
                        Text("Session Notes").appHeadingStyle().foregroundColor(themeManager.secondaryText)
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
                            .appHeadingStyle()
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
        .onAppear(perform: loadSessionData)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    var editCardioInterface: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cardio Metrics").appHeadingStyle().foregroundColor(themeManager.primaryText)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Warm-up (min)").appCaptionStyle().foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $warmUpTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                VStack(alignment: .leading) {
                    Text("Run (min)").appCaptionStyle().foregroundColor(themeManager.secondaryText)
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
                    Text("Cool-down (min)").appCaptionStyle().foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $coolDownTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                VStack(alignment: .leading) {
                    Text("Speed").appCaptionStyle().foregroundColor(themeManager.secondaryText)
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
                    Text("Intensity").appHeadingStyle().foregroundColor(themeManager.primaryText)
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
                Text("Machine Settings").appHeadingStyle().foregroundColor(themeManager.secondaryText)
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(themeManager.primaryText)
            }
            
            Text("Sets").appHeadingStyle().foregroundColor(themeManager.secondaryText)
            
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
                            Text("Reps").appCaptionStyle().foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.reps, format: .number)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Weight").appCaptionStyle().foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                    }
                    
                    HStack {
                        Text("Difficulty").appCaptionStyle().foregroundColor(themeManager.secondaryText)
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
