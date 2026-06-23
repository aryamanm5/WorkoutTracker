import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    @Query(sort: \ExerciseSession.date) var allSessions: [ExerciseSession]
    @Query var workoutDays: [WorkoutDay]
    @Query(sort: \BodyWeightEntry.date) var weightEntries: [BodyWeightEntry]
    
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseType: WorkoutType = .push
    @State private var isCardioExercise = false
    
    @State private var showingAddHistoricalWorkout = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                List {
                    // Appearance Section
                    Section {
                        Toggle(isOn: $themeManager.isDarkMode) {
                            HStack {
                                Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .foregroundColor(themeManager.isDarkMode ? .purple : .orange)
                                Text("Dark Mode")
                                    .foregroundColor(themeManager.primaryText)
                            }
                        }
                        .tint(.appAccent)
                    } header: {
                        Text("Appearance")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    // Manage Exercises Section
                    Section {
                        ForEach(WorkoutType.allCases.filter { $0 != .rest }, id: \.self) { type in
                            let filteredExercises = exercises.filter { $0.type == type }
                            
                            DisclosureGroup {
                                ForEach(filteredExercises) { exercise in
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundColor(themeManager.primaryText)
                                        if exercise.isCardio {
                                            Spacer()
                                            Image(systemName: "figure.run").foregroundColor(.orange)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteExercise(exercise)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            } label: {
                                Text("\(type.rawValue) Exercises (\(filteredExercises.count))")
                                    .foregroundColor(themeManager.primaryText)
                            }
                        }
                    } header: {
                        Text("Manage Exercises")
                            .foregroundColor(themeManager.secondaryText)
                    } footer: {
                        Text("Swipe left on an exercise to delete")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    Section {
                        Button(action: { showingAddExercise = true }) {
                            Label("Add New Exercise", systemImage: "plus.circle.fill")
                                .foregroundColor(Color.appAccent)
                        }
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    // Historical Data Section
                    Section {
                        Button(action: { showingAddHistoricalWorkout = true }) {
                            Label("Add Historical Workout", systemImage: "clock.arrow.circlepath")
                                .foregroundColor(Color.appAccent)
                        }
                    } header: {
                        Text("Historical Data")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    Section {
                        Button(action: exportToCSV) {
                            Label("Export Data to CSV", systemImage: "square.and.arrow.up")
                                .foregroundColor(Color.appAccent)
                        }
                    } header: {
                        Text("Data Management")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    // Legend Section
                    Section {
                        HStack(spacing: 20) {
                            LegendItem(color: .workoutDot, label: "Workout", themeManager: themeManager)
                            LegendItem(color: .cardioDot, label: "Cardio", themeManager: themeManager)
                            LegendItem(color: .creatineDot, label: "Creatine", themeManager: themeManager)
                        }
                        .padding(.vertical, 5)
                    } header: {
                        Text("Calendar Legend")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddExercise) {
                addExerciseSheet
            }
            .sheet(isPresented: $showingAddHistoricalWorkout) {
                AddHistoricalWorkoutView()
                    .environmentObject(themeManager)
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url])
            }            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    var addExerciseSheet: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Exercise Name", text: $newExerciseName)
                            .foregroundColor(themeManager.primaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    Section {
                        Picker("Workout Type", selection: $newExerciseType) {
                            Text("Push").tag(WorkoutType.push)
                            Text("Pull").tag(WorkoutType.pull)
                            Text("Legs").tag(WorkoutType.legs)
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    Section {
                        Toggle("Is this a Cardio Exercise?", isOn: $isCardioExercise)
                            .foregroundColor(themeManager.primaryText)
                            .tint(Color.appAccent)
                    }
                    .listRowBackground(themeManager.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingAddExercise = false }
                        .foregroundColor(themeManager.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        addExercise()
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundColor(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? themeManager.secondaryText : Color.appAccent)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
        }
        .presentationDetents([.medium])
    }
    
    private func addExercise() {
        let exercise = Exercise(name: newExerciseName.trimmingCharacters(in: .whitespaces), type: newExerciseType, isCardio: isCardioExercise)
        context.insert(exercise)
        try? context.save()
        newExerciseName = ""
        isCardioExercise = false
        showingAddExercise = false
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }
    
    private func exportToCSV() {
        var csvString = "Date,Exercise,Type,IsCardio,SetNumber,Reps,Weight(lbs),Difficulty,RestTime(s),SetNotes,MachineSettings,WarmUp(min),Run(min),CoolDown(min),Speed,Intensity,SessionNotes\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Fetch fresh with relationships faulted in
        let descriptor = FetchDescriptor<ExerciseSession>(
            sortBy: [SortDescriptor(\ExerciseSession.date)]
        )

        guard let sessions = try? context.fetch(descriptor) else { return }

        for session in sessions {
            // Access exercise — triggers fault resolution on this context
            guard let exercise = session.exercise else { continue }

            let dateStr = formatter.string(from: session.date)
            let exName = escapeCSV(exercise.name)
            let exType = exercise.type.rawValue
            let isCardio = exercise.isCardio ? "Yes" : "No"
            let settings = escapeCSV(session.machineSettings)
            let sessionNotes = escapeCSV(session.notes)

            if exercise.isCardio {
                let wUp   = session.warmUpTime.map    { String($0) } ?? ""
                let run   = session.runningTime.map   { String($0) } ?? ""
                let cDown = session.coolDownTime.map  { String($0) } ?? ""
                let speed = session.runningSpeed.map  { String($0) } ?? ""
                let intensity = session.intensityRating.map { String($0) } ?? ""

                csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),,,,,,,\(settings),\(wUp),\(run),\(cDown),\(speed),\(intensity),\(sessionNotes)\n")
            } else {
                let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }

                if sortedSets.isEmpty {
                    // Session exists but no sets logged
                    csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),,,,,,,\(settings),,,,,,\(sessionNotes)\n")
                } else {
                    for set in sortedSets {
                        let setNotes  = escapeCSV(set.notes)
                        let restTime  = set.restTimeSeconds.map { String($0) } ?? ""
                        csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(set.setNumber),\(set.reps),\(set.weight),\(set.difficulty),\(restTime),\(setNotes),\(settings),,,,,,\(sessionNotes)\n")
                    }
                }
            }
        }

        // Body weight entries
        if !weightEntries.isEmpty {
            csvString.append("\n\nBody Weight History\nDate,Weight(lbs),Notes\n")
            let fileFormatter = DateFormatter()
            fileFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            for entry in weightEntries {
                let dateStr = fileFormatter.string(from: entry.date)
                let notes = escapeCSV(entry.notes)
                csvString.append("\(dateStr),\(entry.weight),\(notes)\n")
            }
        }

        // Write file
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "WorkoutData_\(fileFormatter.string(from: Date())).csv"

        do {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)

            try csvString.write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )

            print("CSV CREATED:")
            print(fileURL)

            exportURL = fileURL

        } catch {
            print("EXPORT ERROR:")
            print(error)
        }
    }
    
    private func escapeCSV(_ string: String) -> String {
        var result = string.replacingOccurrences(of: "\"", with: "\"\"")
        if result.contains(",") || result.contains("\n") || result.contains("\"") {
            result = "\"\(result)\""
        }
        return result
    }
}

// MARK: - Add Historical Workout View
struct AddHistoricalWorkoutView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    
    @State private var selectedExercise: Exercise?
    @State private var workoutDate = Date()
    @State private var machineSettings = ""
    @State private var sessionNotes = ""
    @State private var sets: [HistoricalSet] = [HistoricalSet()]
    
    // Cardio
    @State private var warmUpTime: Double?
    @State private var runningTime: Double?
    @State private var coolDownTime: Double?
    @State private var runningSpeed: Double?
    @State private var intensityRating: Double = 5
    
    struct HistoricalSet: Identifiable {
        let id = UUID()
        var reps: Int = 0
        var weight: Double = 0
        var difficulty: Int = 3
        var notes: String = ""
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Date Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Date")
                                .appHeadingStyle()
                                .foregroundColor(themeManager.secondaryText)
                            DatePicker("", selection: $workoutDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.appAccent)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                        
                        // Exercise Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exercise")
                                .appHeadingStyle()
                                .foregroundColor(themeManager.secondaryText)
                            
                            Menu {
                                ForEach(exercises) { exercise in
                                    Button(exercise.name) {
                                        selectedExercise = exercise
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedExercise?.name ?? "Select Exercise")
                                        .foregroundColor(selectedExercise == nil ? themeManager.secondaryText : themeManager.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(themeManager.secondaryText)
                                }
                                .padding()
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                        
                        if let exercise = selectedExercise {
                            if exercise.isCardio {
                                cardioInputSection
                            } else {
                                strengthInputSection
                            }
                        }
                        
                        // Session Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Session Notes")
                                .appHeadingStyle()
                                .foregroundColor(themeManager.secondaryText)
                            TextEditor(text: $sessionNotes)
                                .frame(height: 80)
                                .padding(8)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(10)
                                .foregroundColor(themeManager.primaryText)
                                .scrollContentBackground(.hidden)
                        }
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(12)
                        
                        // Save Button
                        Button(action: saveHistoricalWorkout) {
                            Text("Save Historical Workout")
                                .appHeadingStyle()
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedExercise == nil ? Color.gray : Color.appAccent)
                                .cornerRadius(15)
                        }
                        .disabled(selectedExercise == nil)
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Historical Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    var cardioInputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cardio Metrics")
                .appHeadingStyle()
                .foregroundColor(themeManager.primaryText)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Warm-up (min)")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $warmUpTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                
                VStack(alignment: .leading) {
                    Text("Run (min)")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $runningTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Cool-down (min)")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $coolDownTime, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
                
                VStack(alignment: .leading) {
                    Text("Speed")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                    TextField("0", value: $runningSpeed, format: .number)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(8)
                        .foregroundColor(themeManager.primaryText)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Intensity")
                        .foregroundColor(themeManager.primaryText)
                    Spacer()
                    Text("\(Int(intensityRating))/10")
                        .fontWeight(.bold)
                        .foregroundColor(Color.appAccent)
                }
                Slider(value: $intensityRating, in: 1...10, step: 1)
                    .tint(.appAccent)
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(12)
    }
    
    var strengthInputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Sets")
                .appHeadingStyle()
                .foregroundColor(themeManager.primaryText)
            
            // Machine Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Machine Settings")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .padding()
                    .background(themeManager.secondaryBackground)
                    .cornerRadius(8)
                    .foregroundColor(themeManager.primaryText)
            }
            
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Set \(index + 1)")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.appAccent)
                        Spacer()
                        if sets.count > 1 {
                            Button(action: { sets.remove(at: index) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .appCaptionStyle()
                            }
                        }
                    }
                    
                    HStack(spacing: 15) {
                        VStack(alignment: .leading) {
                            Text("Reps")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $sets[index].reps, format: .number)
                                .keyboardType(.numberPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Weight (lbs)")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $sets[index].weight, format: .number)
                                .keyboardType(.decimalPad)
                                .padding(10)
                                .background(themeManager.secondaryBackground)
                                .cornerRadius(8)
                                .foregroundColor(themeManager.primaryText)
                        }
                    }
                    
                    HStack {
                        Text("Difficulty")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                        Spacer()
                        DifficultyDots(rating: sets[index].difficulty, size: 18, interactive: true) { newRating in
                            sets[index].difficulty = newRating
                        }
                    }
                }
                .padding()
                .background(themeManager.secondaryBackground)
                .cornerRadius(10)
            }
            
            Button(action: { sets.append(HistoricalSet()) }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Set")
                }
                .foregroundColor(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.appAccent.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(12)
    }
    
    private func saveHistoricalWorkout() {
        guard let exercise = selectedExercise else { return }
        
        let session = ExerciseSession(
            date: workoutDate,
            machineSettings: machineSettings,
            totalSets: exercise.isCardio ? 1 : sets.count,
            notes: sessionNotes,
            warmUpTime: warmUpTime,
            runningTime: runningTime,
            coolDownTime: coolDownTime,
            runningSpeed: runningSpeed,
            intensityRating: exercise.isCardio ? Int(intensityRating) : nil
        )
        context.insert(session)
        
        if !exercise.isCardio {
            for (index, set) in sets.enumerated() {
                let loggedSet = LoggedSet(
                    setNumber: index + 1,
                    reps: set.reps,
                    weight: set.weight,
                    notes: set.notes,
                    difficulty: set.difficulty,
                    restTimeSeconds: nil
                )
                context.insert(loggedSet)
                loggedSet.session = session
            }
        }
        
        session.exercise = exercise
        
        do {
            try context.save()
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            dismiss()
        } catch {
            print("Error saving historical workout: \(error)")
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {

        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
