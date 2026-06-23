import SwiftUI
import SwiftData

struct CurrentWorkoutView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(AppRouter.self) var router
    @Environment(WorkoutViewModel.self) var viewModel
    
    @State private var selectedWorkoutType: WorkoutType = .push
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack(path: Bindable(router).path) {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // Header Gradient Card
                        VStack(spacing: 10) {
                            Text("Ready to crush it?")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .textCase(.uppercase)
                            
                            Text(selectedWorkoutType == .rest ? "Rest Day" : "\(selectedWorkoutType.rawValue) Day")
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            
                            if selectedWorkoutType != .rest {
                                Text("Let's build some muscle.")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [themeManager.gradientStart, themeManager.gradientEnd]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Override Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Change Today's Split")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryText)
                                .padding(.horizontal)
                            
                            Picker("Workout Type", selection: $selectedWorkoutType) {
                                Text("Push").tag(WorkoutType.push)
                                Text("Pull").tag(WorkoutType.pull)
                                Text("Legs").tag(WorkoutType.legs)
                                Text("Rest").tag(WorkoutType.rest)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                        
                        if selectedWorkoutType != .rest {
                            Button(action: {
                                hapticFeedback()
                                router.path.append(selectedWorkoutType)
                            }) {
                                HStack {
                                    Text("Start Workout")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(15)
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 5, x: 0, y: 5)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        } else {
                            VStack(spacing: 15) {
                                Image(systemName: "bed.double.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(themeManager.secondaryText.opacity(0.6))
                                Text("Take it easy today. Recovery is where the growth happens!")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(themeManager.secondaryText)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 40)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: WorkoutType.self) { type in
                ExerciseListView(workoutType: type)
                    .environmentObject(themeManager)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseHistoryView(exercise: exercise)
                    .environmentObject(themeManager)
            }
            .navigationDestination(for: String.self) { _ in EmptyView() }
            .onAppear {
                if !hasAppeared {
                    selectedWorkoutType = viewModel.getTodayWorkoutType()
                    hasAppeared = true
                }
            }
        }
        .tint(.appAccent)
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    private func hapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Exercise List View
struct ExerciseListView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(WorkoutViewModel.self) var viewModel
    @Query var exercises: [Exercise]
    let workoutType: WorkoutType
    
    init(workoutType: WorkoutType) {
        self.workoutType = workoutType
        let rawValue = workoutType.rawValue
        _exercises = Query(filter: #Predicate<Exercise> { $0.typeRawValue == rawValue }, sort: \.name)
    }
    
    var body: some View {
        List {
            ForEach(exercises) { exercise in
                NavigationLink(value: exercise) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryText)
                                if exercise.isCardio {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(.orange)
                                        .padding(.leading, 5)
                                }
                            }
                            
                            if exercise.shouldIncreaseWeight, let suggested = exercise.suggestedNextWeight {
                                Text("Suggested: \(suggested, specifier: "%.1f") lbs")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                        
                        if viewModel.isExerciseCompletedToday(exercise) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(themeManager.secondaryText.opacity(0.3))
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(themeManager.cardBackground)
            }
        }
        .scrollContentBackground(.hidden)
        .background(themeManager.background)
        .listStyle(.insetGrouped)
        .navigationTitle("\(workoutType.rawValue) Routine")
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Exercise History View
struct ExerciseHistoryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(AppRouter.self) var router
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise
    
    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                if exercise.shouldIncreaseWeight, let suggested = exercise.suggestedNextWeight {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.green)
                        Text("Suggested weight: \(suggested, specifier: "%.1f") lbs")
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                
                if let previousSession = viewModel.getPreviousSession(for: exercise) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Last Session: \(previousSession.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryText)
                            .textCase(.uppercase)
                        
                        if exercise.isCardio {
                            if let run = previousSession.runningTime { Text("Run: \(run, specifier: "%.1f") min").foregroundColor(themeManager.primaryText) }
                            if let speed = previousSession.runningSpeed { Text("Speed: \(speed, specifier: "%.1f")").foregroundColor(themeManager.primaryText) }
                            if let intensity = previousSession.intensityRating { Text("Felt like: \(intensity)/10").foregroundColor(themeManager.primaryText) }
                        } else {
                            if !previousSession.machineSettings.isEmpty {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .foregroundColor(themeManager.secondaryText)
                                    Text(previousSession.machineSettings)
                                        .fontWeight(.medium)
                                        .foregroundColor(themeManager.primaryText)
                                }
                                Divider().background(themeManager.secondaryText)
                            }
                            
                            let sortedSets = previousSession.sets.sorted(by: { $0.setNumber < $1.setNumber })
                            
                            ForEach(sortedSets) { set in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Set \(set.setNumber)").foregroundColor(themeManager.secondaryText)
                                        Spacer()
                                        Text("\(set.reps) reps").foregroundColor(themeManager.primaryText)
                                        Spacer()
                                        Text("\(set.weight, specifier: "%.1f") lbs").fontWeight(.bold).foregroundColor(themeManager.primaryText)
                                        Spacer()
                                        DifficultyDots(rating: set.difficulty, size: 8)
                                        if let rest = set.restTimeSeconds {
                                            Text("\(rest)s")
                                                .font(.caption)
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
                                .font(.body)
                            }
                        }
                        
                        if !previousSession.notes.isEmpty {
                            Divider().background(themeManager.secondaryText)
                            Text("Session Notes: \(previousSession.notes)")
                                .font(.caption)
                                .foregroundColor(themeManager.secondaryText)
                        }
                    }
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    .padding(.top, previousSession.exercise?.shouldIncreaseWeight == true ? 0 : 20)
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(Color.appAccent.opacity(0.5))
                        Text("No previous history for \(exercise.name).")
                            .foregroundColor(themeManager.secondaryText)
                        Text("Time to set your baseline!")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                }
                
                Spacer()
                
                NavigationLink(destination: WorkoutLoggingView(exercise: exercise).environmentObject(themeManager)) {
                    Text("Log Workout")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appAccent)
                        .cornerRadius(15)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 5, x: 0, y: 5)
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Difficulty Dots View
struct DifficultyDots: View {
    let rating: Int
    var size: CGFloat = 12
    var interactive: Bool = false
    var onTap: ((Int) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= rating ? difficultyColor(for: rating) : Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .onTapGesture {
                        if interactive {
                            onTap?(index)
                        }
                    }
            }
        }
    }
    
    func difficultyColor(for rating: Int) -> Color {
        switch rating {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

struct TempSet: Identifiable {
    let id = UUID()
    let setNumber: Int
    let reps: Int
    let weight: Double
    let notes: String
    let difficulty: Int
    let restTimeSeconds: Int?
}

// MARK: - Rest Timer View
struct RestTimerView: View {
    @Binding var seconds: Int
    let isRunning: Bool
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .foregroundColor(isRunning ? .orange : themeManager.secondaryText)
            Text(formatTime(seconds))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isRunning ? .orange : themeManager.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(themeManager.cardBackground)
        .cornerRadius(8)
    }
    
    func formatTime(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Workout Logging View
struct WorkoutLoggingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) var router
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise
    
    // Strength State
    @State private var currentSetNumber: Int = 1
    @State private var reps: Int = 0
    @State private var weight: Double? = nil
    @State private var machineSettings: String = ""
    @State private var recordedSets: [TempSet] = []
    @State private var currentNotes: String = ""
    @State private var currentDifficulty: Int = 3
    
    // Rest Timer
    @State private var restTimerSeconds: Int = 0
    @State private var restTimerRunning: Bool = false
    @State private var lastRestTime: Int? = nil
    @State private var timerTask: Task<Void, Never>? = nil
    
    // Plate Calculator Toggle
    @State private var showPlateCalculator: Bool = false
    
    // Weight Increase Suggestion
    @State private var shouldIncreaseWeight: Bool = false
    @State private var suggestedNextWeight: Double? = nil
    
    // Cardio State
    @State private var warmUpTime: Double? = nil
    @State private var runningTime: Double? = nil
    @State private var coolDownTime: Double? = nil
    @State private var runningSpeed: Double? = nil
    @State private var intensityRating: Double = 5.0
    
    @State private var sessionNotes: String = ""
    
    var canSaveSet: Bool {
        reps > 0
    }
    
    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    if exercise.isCardio {
                        cardioInterface
                    } else {
                        strengthInterface
                    }
                    
                    // Weight Increase Section
                    if !exercise.isCardio {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $shouldIncreaseWeight) {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Increase weight next time?")
                                        .foregroundColor(themeManager.primaryText)
                                }
                            }
                            .tint(.green)
                            
                            if shouldIncreaseWeight {
                                HStack {
                                    Text("Next weight:")
                                        .foregroundColor(themeManager.secondaryText)
                                    TextField("lbs", value: $suggestedNextWeight, format: .number)
                                        .keyboardType(.decimalPad)
                                        .padding(10)
                                        .background(themeManager.cardBackground)
                                        .cornerRadius(8)
                                        .frame(width: 100)
                                        .foregroundColor(themeManager.primaryText)
                                }
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    // Session Notes Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Notes").font(.headline).foregroundColor(themeManager.secondaryText)
                        TextEditor(text: $sessionNotes)
                            .frame(height: 60)
                            .padding(8)
                            .background(themeManager.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(themeManager.primaryText)
                            .scrollContentBackground(.hidden)
                    }
                    
                    // Recorded Sets Summary
                    if !recordedSets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Completed Sets").font(.headline).foregroundColor(themeManager.secondaryText)
                            
                            ForEach(recordedSets) { set in
                                HStack {
                                    Text("Set \(set.setNumber)")
                                        .foregroundColor(themeManager.secondaryText)
                                    Spacer()
                                    Text("\(set.reps) reps")
                                        .foregroundColor(themeManager.primaryText)
                                    Spacer()
                                    Text("\(set.weight, specifier: "%.1f") lbs")
                                        .fontWeight(.bold)
                                        .foregroundColor(themeManager.primaryText)
                                    DifficultyDots(rating: set.difficulty, size: 6)
                                    if let rest = set.restTimeSeconds {
                                        Text("\(rest)s")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding(.vertical, 4)
                                
                                if !set.notes.isEmpty {
                                    Text(set.notes)
                                        .font(.caption)
                                        .foregroundColor(themeManager.secondaryText)
                                        .italic()
                                }
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Bottom Buttons
                    VStack(spacing: 15) {
                        if !exercise.isCardio {
                            Button(action: saveNextSet) {
                                Text("Save Set & Next")
                                    .font(.headline)
                                    .foregroundColor(canSaveSet ? Color.appAccent : themeManager.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(canSaveSet ? Color.appAccent.opacity(0.2) : themeManager.secondaryText.opacity(0.1))
                                    .cornerRadius(15)
                            }
                            .disabled(!canSaveSet)
                        }
                        
                        Button(action: saveAndFinish) {
                            Text("Finish Exercise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .cornerRadius(15)
                                .shadow(color: Color.appAccent.opacity(0.3), radius: 5, x: 0, y: 5)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                RestTimerView(seconds: $restTimerSeconds, isRunning: restTimerRunning)
                    .environmentObject(themeManager)
            }
        }
        .onAppear {
            setupFromPreviousSession()
            startRestTimer()
        }
        .onDisappear {
            timerTask?.cancel()
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
    
    private func setupFromPreviousSession() {
        if let prev = viewModel.getPreviousSession(for: exercise) {
            machineSettings = prev.machineSettings
        }
        
        if exercise.shouldIncreaseWeight, let suggested = exercise.suggestedNextWeight {
            weight = suggested
        }
        
        let plateMathExercises = ["bench press", "leg press"]
        showPlateCalculator = plateMathExercises.contains(where: { exercise.name.lowercased().contains($0) })
    }
    
    private func startRestTimer() {
        restTimerRunning = true
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if !Task.isCancelled {
                    await MainActor.run {
                        restTimerSeconds += 1
                    }
                }
            }
        }
    }
    
    private func resetRestTimer() {
        lastRestTime = restTimerSeconds
        restTimerSeconds = 0
    }
    
    var strengthInterface: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack {
                Text("Current Set")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryText)
                Spacer()
                Text("\(currentSetNumber)")
                    .font(.title)
                    .fontWeight(.heavy)
                    .foregroundColor(Color.appAccent)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 5)
                    .background(Color.appAccent.opacity(0.15))
                    .cornerRadius(10)
            }
            
            // Reps Counter
            VStack(alignment: .leading, spacing: 10) {
                Text("Reps Completed").font(.headline).foregroundColor(themeManager.secondaryText)
                HStack {
                    Button(action: { if reps > 0 { reps -= 1; triggerHaptic() } }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 40)).foregroundColor(.red.opacity(0.8))
                    }
                    Spacer()
                    Text("\(reps)")
                        .font(.system(size: 45, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                    Button(action: { reps += 1; triggerHaptic() }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundColor(Color.appAccent)
                    }
                }
                .padding()
                .background(themeManager.cardBackground)
                .cornerRadius(16)
            }
            
            // Difficulty Rating
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Difficulty").font(.headline).foregroundColor(themeManager.secondaryText)
                    Spacer()
                    Text(difficultyLabel(for: currentDifficulty))
                        .font(.caption)
                        .foregroundColor(difficultyColor(for: currentDifficulty))
                }
                
                DifficultyDots(rating: currentDifficulty, size: 24, interactive: true) { newRating in
                    currentDifficulty = newRating
                    triggerHaptic()
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(themeManager.cardBackground)
            .cornerRadius(16)
            
            // Weight Input / Plate Calculator
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Weight (lbs)").font(.headline).foregroundColor(themeManager.secondaryText)
                    Spacer()
                    Toggle("Plate Math", isOn: $showPlateCalculator.animation(.spring()))
                        .labelsHidden()
                        .tint(.appAccent)
                    Text("Plate Math").font(.caption).foregroundColor(themeManager.secondaryText)
                }
                
                if showPlateCalculator {
                    PlateCalculatorView(weight: $weight)
                        .environmentObject(themeManager)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    TextField("Enter weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                        .font(.title3)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            // Machine Settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Machine Settings").font(.headline).foregroundColor(themeManager.secondaryText)
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(themeManager.primaryText)
            }
            
            // Per-Set Notes
            VStack(alignment: .leading, spacing: 10) {
                Text("Set \(currentSetNumber) Notes").font(.headline).foregroundColor(themeManager.secondaryText)
                TextField("Notes for this set...", text: $currentNotes)
                    .padding()
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
                    .foregroundColor(themeManager.primaryText)
            }
        }
    }
    
    var cardioInterface: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cardio Metrics")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryText)
            
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
                    TextField("e.g. 6.5", value: $runningSpeed, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("How did it feel?").font(.headline).foregroundColor(themeManager.primaryText)
                    Spacer()
                    Text("\(Int(intensityRating))/10").fontWeight(.bold).foregroundColor(Color.appAccent)
                }
                Slider(value: $intensityRating, in: 1...10, step: 1) {
                    Text("Intensity")
                } minimumValueLabel: {
                    Text("Easy").font(.caption).foregroundColor(themeManager.secondaryText)
                } maximumValueLabel: {
                    Text("Hard").font(.caption).foregroundColor(themeManager.secondaryText)
                }
                .tint(.appAccent)
            }
            .padding()
            .background(themeManager.cardBackground)
            .cornerRadius(15)
        }
    }
    
    private func difficultyLabel(for rating: Int) -> String {
        switch rating {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Moderate"
        }
    }
    
    private func difficultyColor(for rating: Int) -> Color {
        switch rating {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
    
    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func saveNextSet() {
        guard canSaveSet else { return }
        
        let safeWeight = weight ?? 0.0
        let newSet = TempSet(
            setNumber: currentSetNumber,
            reps: reps,
            weight: safeWeight,
            notes: currentNotes,
            difficulty: currentDifficulty,
            restTimeSeconds: currentSetNumber > 1 ? lastRestTime : nil
        )
        recordedSets.append(newSet)
        
        currentSetNumber += 1
        reps = 0
        currentNotes = ""
        currentDifficulty = 3
        resetRestTimer()
        triggerHaptic()
    }
    
    private func saveAndFinish() {
        let session = ExerciseSession(
            date: Date(),
            machineSettings: machineSettings,
            totalSets: exercise.isCardio ? 1 : (canSaveSet ? recordedSets.count + 1 : recordedSets.count),
            notes: sessionNotes,
            warmUpTime: warmUpTime,
            runningTime: runningTime,
            coolDownTime: coolDownTime,
            runningSpeed: runningSpeed,
            intensityRating: exercise.isCardio ? Int(intensityRating) : nil
        )
        context.insert(session)
        
        if !exercise.isCardio {
            if canSaveSet {
                let safeWeight = weight ?? 0.0
                let finalSet = TempSet(
                    setNumber: currentSetNumber,
                    reps: reps,
                    weight: safeWeight,
                    notes: currentNotes,
                    difficulty: currentDifficulty,
                    restTimeSeconds: currentSetNumber > 1 ? restTimerSeconds : nil
                )
                recordedSets.append(finalSet)
            }
            
            for tempSet in recordedSets {
                let loggedSet = LoggedSet(
                    setNumber: tempSet.setNumber,
                    reps: tempSet.reps,
                    weight: tempSet.weight,
                    notes: tempSet.notes,
                    difficulty: tempSet.difficulty,
                    restTimeSeconds: tempSet.restTimeSeconds
                )
                context.insert(loggedSet)
                loggedSet.session = session
            }
            
            exercise.shouldIncreaseWeight = shouldIncreaseWeight
            exercise.suggestedNextWeight = suggestedNextWeight
        }
        
        session.exercise = exercise
        
        do {
            try context.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            
            router.popToRoot()
        } catch {
            print("Error saving session: \(error)")
        }
    }
}

// MARK: - Premium Interactive Plate Calculator
struct PlateCalculatorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var weight: Double?
    
    @State private var barWeight: Double = 45.0
    @State private var plates: [Double] = []
    
    let availablePlates: [Double] = [45, 35, 25, 10, 5, 2.5]
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Total Weight Readout
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", (weight ?? barWeight)))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.appAccent)
                    .contentTransition(.numericText())
                Text("lbs")
                    .font(.headline)
                    .foregroundColor(themeManager.secondaryText)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: weight)
            
            // The Barbell Visual
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 12)
                    .cornerRadius(6)
                
                HStack(spacing: 2) {
                    Spacer()
                    
                    HStack(spacing: 2) {
                        ForEach(plates.reversed().indices, id: \.self) { i in
                            PlateVisual(val: plates.reversed()[i])
                                .onTapGesture { removePlate(at: plates.count - 1 - i) }
                        }
                    }
                    
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)
                    Spacer().frame(width: 80)
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)
                    
                    HStack(spacing: 2) {
                        ForEach(plates.indices, id: \.self) { i in
                            PlateVisual(val: plates[i])
                                .onTapGesture { removePlate(at: i) }
                        }
                    }
                    
                    Spacer()
                }
            }
            .frame(height: 100)
            .padding(.vertical, 10)
            
            VStack(spacing: 15) {
                HStack {
                    Text("Bar:")
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                    Picker("Bar Weight", selection: $barWeight) {
                        Text("45 lb").tag(45.0)
                        Text("35 lb").tag(35.0)
                        Text("15 lb").tag(15.0)
                        Text("Smith (25)").tag(25.0)
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.primaryText)
                    
                    Spacer()
                    
                    Button("Clear Bar") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            plates.removeAll()
                            updateWeight()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availablePlates, id: \.self) { plateVal in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    plates.append(plateVal)
                                    plates.sort(by: >)
                                    updateWeight()
                                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                                    impact.impactOccurred()
                                }
                            }) {
                                VStack {
                                    Text("+\(String(format: "%g", plateVal))")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .frame(width: 55, height: 55)
                                .background(plateColor(for: plateVal))
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 5)
                }
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(16)
        .onAppear {
            if let currentW = weight, currentW >= barWeight {
                calculatePlatesFor(target: currentW)
            } else {
                updateWeight()
            }
        }
        .onChange(of: barWeight) {
            updateWeight()
        }
    }
    
    private func updateWeight() {
        let total = barWeight + (plates.reduce(0, +) * 2)
        weight = total
    }
    
    private func removePlate(at index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            plates.remove(at: index)
            updateWeight()
            let impact = UIImpactFeedbackGenerator(style: .soft)
            impact.impactOccurred()
        }
    }
    
    private func calculatePlatesFor(target: Double) {
        var remainingWeight = (target - barWeight) / 2.0
        var newPlates: [Double] = []
        
        for p in availablePlates {
            while remainingWeight >= p {
                newPlates.append(p)
                remainingWeight -= p
            }
        }
        plates = newPlates
    }
    
    private func plateColor(for val: Double) -> Color {
        switch val {
        case 45: return Color.red.opacity(0.9)
        case 35: return Color.blue.opacity(0.9)
        case 25: return Color.green.opacity(0.9)
        case 10: return Color.black.opacity(0.8)
        case 5: return Color.black.opacity(0.8)
        default: return Color.gray
        }
    }
}

struct PlateVisual: View {
    let val: Double
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(plateColor)
                .frame(width: thickness, height: height)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 2, y: 0)
            
            Text(String(format: "%g", val))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .rotationEffect(.degrees(-90))
        }
    }
    
    var height: CGFloat {
        switch val {
        case 45, 35: return 85
        case 25: return 70
        case 10: return 55
        case 5: return 40
        default: return 30
        }
    }
    
    var thickness: CGFloat {
        switch val {
        case 45: return 18
        case 35: return 15
        case 25: return 12
        case 10: return 10
        case 5: return 8
        default: return 6
        }
    }
    
    var plateColor: Color {
        switch val {
        case 45: return Color.red.opacity(0.9)
        case 35: return Color.blue.opacity(0.9)
        case 25: return Color.green.opacity(0.9)
        case 10: return Color.black.opacity(0.8)
        case 5: return Color.black.opacity(0.8)
        default: return Color.gray
        }
    }
}
