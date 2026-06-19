import SwiftUI
import SwiftData

// MARK: - Global Theme
// Change this single color to instantly re-theme your entire app!
extension Color {
    static let appAccent = Color.indigo
}

struct CurrentWorkoutView: View {
    @Environment(AppRouter.self) var router
    @Environment(WorkoutViewModel.self) var viewModel
    
    @State private var selectedWorkoutType: WorkoutType = .push
    @State private var hasAppeared = false
    
    var body: some View {
        NavigationStack(path: Bindable(router).path) {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
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
                            LinearGradient(gradient: Gradient(colors: [Color.appAccent, Color.appAccent.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .cornerRadius(20)
                        .shadow(color: Color.appAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Override Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Change Today's Split")
                                .font(.headline)
                                .foregroundColor(.secondary)
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
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("Take it easy today. Recovery is where the growth happens!")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 40)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: WorkoutType.self) { type in
                ExerciseListView(workoutType: type)
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseHistoryView(exercise: exercise)
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
    }
    
    private func hapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Exercise List View
struct ExerciseListView: View {
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
                        Text(exercise.name)
                            .font(.headline)
                        if exercise.isCardio {
                            Image(systemName: "figure.run")
                                .foregroundColor(.orange)
                                .padding(.leading, 5)
                        }
                        Spacer()
                        if viewModel.isExerciseCompletedToday(exercise) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.3))
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(workoutType.rawValue) Routine")
    }
}

// MARK: - Exercise History View
struct ExerciseHistoryView: View {
    @Environment(AppRouter.self) var router
    @Environment(WorkoutViewModel.self) var viewModel
    let exercise: Exercise
    
    var body: some View {
        VStack(spacing: 20) {
            if let previousSession = viewModel.getPreviousSession(for: exercise) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Last Session: \(previousSession.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    if exercise.isCardio {
                        if let run = previousSession.runningTime { Text("Run: \(run, specifier: "%.1f") min") }
                        if let speed = previousSession.runningSpeed { Text("Speed: \(speed, specifier: "%.1f")") }
                        if let intensity = previousSession.intensityRating { Text("Felt like: \(intensity)/10") }
                    } else {
                        if !previousSession.machineSettings.isEmpty {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.gray)
                                Text(previousSession.machineSettings)
                                    .fontWeight(.medium)
                            }
                            Divider()
                        }
                        
                        let sortedSets = previousSession.sets.sorted(by: { $0.setNumber < $1.setNumber })
                        
                        ForEach(sortedSets) { set in
                            HStack {
                                Text("Set \(set.setNumber)").foregroundColor(.secondary)
                                Spacer()
                                Text("\(set.reps) reps")
                                Spacer()
                                Text("\(set.weight, specifier: "%.1f") lbs").fontWeight(.bold)
                            }
                            .font(.body)
                        }
                    }
                    
                    if !previousSession.notes.isEmpty {
                        Divider()
                        Text("Notes: \(previousSession.notes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .padding(.top, 20)
            } else {
                VStack(spacing: 15) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(Color.appAccent.opacity(0.5))
                    Text("No previous history for \(exercise.name).")
                        .foregroundColor(.secondary)
                    Text("Time to set your baseline!")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            
            Spacer()
            
            NavigationLink(destination: WorkoutLoggingView(exercise: exercise)) {
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
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(exercise.name)
    }
}

struct TempSet {
    let setNumber: Int
    let reps: Int
    let weight: Double
}

// MARK: - Workout Logging View
struct WorkoutLoggingView: View {
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
    
    // Plate Calculator Toggle
    @State private var showPlateCalculator: Bool = false
    
    // Cardio State
    @State private var warmUpTime: Double? = nil
    @State private var runningTime: Double? = nil
    @State private var coolDownTime: Double? = nil
    @State private var runningSpeed: Double? = nil
    @State private var intensityRating: Double = 5.0
    
    @State private var notes: String = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    if exercise.isCardio {
                        cardioInterface
                    } else {
                        strengthInterface
                    }
                    
                    // Shared Notes Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Notes").font(.headline).foregroundColor(.secondary)
                        TextEditor(text: $notes)
                            .frame(height: 80)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                    
                    Spacer(minLength: 40)
                    
                    // Bottom Buttons
                    VStack(spacing: 15) {
                        if !exercise.isCardio {
                            Button(action: saveNextSet) {
                                Text("Save Set & Next")
                                    .font(.headline)
                                    .foregroundColor(Color.appAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.appAccent.opacity(0.1))
                                    .cornerRadius(15)
                            }
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
        .onAppear {
            if let prev = viewModel.getPreviousSession(for: exercise) {
                machineSettings = prev.machineSettings
            }
            // Auto-show plate calculator for common barbell exercises
            let barbellKeywords = ["bench", "squat", "deadlift", "press"]
            if barbellKeywords.contains(where: { exercise.name.lowercased().contains($0) }) {
                showPlateCalculator = true
            }
        }
    }
    
    var strengthInterface: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack {
                Text("Current Set")
                    .font(.title2)
                    .fontWeight(.bold)
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
                Text("Reps Completed").font(.headline).foregroundColor(.secondary)
                HStack {
                    Button(action: { if reps > 0 { reps -= 1; triggerHaptic() } }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 40)).foregroundColor(.red.opacity(0.8))
                    }
                    Spacer()
                    Text("\(reps)").font(.system(size: 45, weight: .bold, design: .rounded))
                    Spacer()
                    Button(action: { reps += 1; triggerHaptic() }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundColor(Color.appAccent)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            }
            
            // Weight Input / Plate Calculator
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Weight (lbs)").font(.headline).foregroundColor(.secondary)
                    Spacer()
                    Toggle("Plate Math", isOn: $showPlateCalculator.animation(.spring()))
                        .labelsHidden()
                        .tint(.appAccent)
                    Text("Plate Math").font(.caption).foregroundColor(.secondary)
                }
                
                if showPlateCalculator {
                    PlateCalculatorView(weight: $weight)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    TextField("Enter weight", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .font(.title3)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
            }
            
            // Machine Settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Machine Settings").font(.headline).foregroundColor(.secondary)
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }
        }
    }
    
    var cardioInterface: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cardio Metrics").font(.title2).fontWeight(.bold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Warm-up (min)").font(.caption).foregroundColor(.secondary)
                    TextField("0", value: $warmUpTime, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Run (min)").font(.caption).foregroundColor(.secondary)
                    TextField("0", value: $runningTime, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cool-down (min)").font(.caption).foregroundColor(.secondary)
                    TextField("0", value: $coolDownTime, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading) {
                    Text("Speed").font(.caption).foregroundColor(.secondary)
                    TextField("e.g. 6.5", value: $runningSpeed, format: .number).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("How did it feel?").font(.headline)
                    Spacer()
                    Text("\(Int(intensityRating))/10").fontWeight(.bold).foregroundColor(Color.appAccent)
                }
                Slider(value: $intensityRating, in: 1...10, step: 1) {
                    Text("Intensity")
                } minimumValueLabel: {
                    Text("Easy").font(.caption).foregroundColor(.secondary)
                } maximumValueLabel: {
                    Text("Hard").font(.caption).foregroundColor(.secondary)
                }
                .tint(.appAccent)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(15)
        }
    }
    
    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private func saveNextSet() {
        let safeWeight = weight ?? 0.0
        let newSet = TempSet(setNumber: currentSetNumber, reps: reps, weight: safeWeight)
        recordedSets.append(newSet)
        
        currentSetNumber += 1
        reps = 0
        // We keep weight the same so the user doesn't have to re-enter or re-rack plates for the next set
        triggerHaptic()
    }
    
    private func saveAndFinish() {
        let session = ExerciseSession(
            date: Date(),
            machineSettings: machineSettings,
            totalSets: exercise.isCardio ? 1 : recordedSets.count + 1,
            notes: notes,
            warmUpTime: warmUpTime,
            runningTime: runningTime,
            coolDownTime: coolDownTime,
            runningSpeed: runningSpeed,
            intensityRating: exercise.isCardio ? Int(intensityRating) : nil
        )
        context.insert(session)
        
        if !exercise.isCardio {
            saveNextSet()
            for tempSet in recordedSets {
                let loggedSet = LoggedSet(setNumber: tempSet.setNumber, reps: tempSet.reps, weight: tempSet.weight)
                context.insert(loggedSet)
                loggedSet.session = session
            }
        }
        
        session.exercise = exercise
        
        do {
            try context.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            
            router.popToRoot()
            while router.path.count > 1 {
                router.path.removeLast()
            }
        } catch {
            print("Error saving session: \(error)")
        }
    }
}

// MARK: - Premium Interactive Plate Calculator
struct PlateCalculatorView: View {
    @Binding var weight: Double?
    
    @State private var barWeight: Double = 45.0
    @State private var plates: [Double] = [] // Represents one side of the bar
    
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
                    .foregroundColor(.secondary)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: weight)
            
            // The Barbell Visual
            ZStack {
                // Background Bar
                Rectangle()
                    .fill(LinearGradient(colors: [.gray.opacity(0.4), .gray.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 12)
                    .cornerRadius(6)
                
                HStack(spacing: 2) {
                    Spacer()
                    
                    // Left Plates (Reversed for symmetry)
                    HStack(spacing: 2) {
                        ForEach(plates.reversed().indices, id: \.self) { i in
                            PlateVisual(val: plates.reversed()[i])
                                .onTapGesture { removePlate(at: plates.count - 1 - i) }
                        }
                    }
                    
                    // Left Collar
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)
                    
                    // Center Bar Gap
                    Spacer().frame(width: 80)
                    
                    // Right Collar
                    RoundedRectangle(cornerRadius: 2).fill(Color.gray).frame(width: 12, height: 25)
                    
                    // Right Plates
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
            
            // Controls
            VStack(spacing: 15) {
                // Bar selector
                HStack {
                    Text("Bar:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Bar Weight", selection: $barWeight) {
                        Text("45 lb").tag(45.0)
                        Text("167 lb").tag(167.0)
                        Text("15 lb").tag(15.0)
                        Text("Smith (25)").tag(25.0) // Typical smith machine starting weight
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    
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
                
                // Plate Adder Buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availablePlates, id: \.self) { plateVal in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    plates.append(plateVal)
                                    plates.sort(by: >) // Keep heavy plates inside
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .onAppear {
            // If they already entered a weight, try to calculate the plates automatically!
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
    
    // Auto-rack plates if user manually typed a weight first
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
    
    // Helper to color the buttons like real bumper plates
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
            
            // Little text on the plate
            Text(String(format: "%g", val))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .rotationEffect(.degrees(-90))
        }
    }
    
    // Sizes to mimic real plates
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
