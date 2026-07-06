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
    @State private var showingCSVImporter = false
    @State private var importMessage: String?

    @AppStorage("legPressSledWeight") private var legPressSledWeight: Double = 167
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                List {
                    // Appearance Section
                    Section {
                        Picker(selection: $themeManager.appearance) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.rawValue).tag(appearance)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(Color.appAccent)
                                Text("Theme")
                                    .foregroundColor(themeManager.primaryText)
                            }
                        }

                        Picker(selection: $themeManager.selectedFont) {
                            ForEach(AppFontChoice.allCases) { fontChoice in
                                Text(fontChoice.rawValue).tag(fontChoice)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "textformat")
                                    .foregroundColor(Color.appAccent)
                                Text("Font")
                                    .foregroundColor(themeManager.primaryText)
                            }
                        }
                    } header: {
                        Text("Appearance")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)

                    // Plate Math Section
                    Section {
                        HStack {
                            Text("Leg Press Sled Weight")
                                .foregroundColor(themeManager.primaryText)
                            Spacer()
                            TextField("167", value: $legPressSledWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .foregroundColor(themeManager.primaryText)
                            Text("lbs")
                                .foregroundColor(themeManager.secondaryText)
                        }
                    } header: {
                        Text("Plate Math")
                            .foregroundColor(themeManager.secondaryText)
                    } footer: {
                        Text("Starting weight of your gym's leg press sled, used by the plate calculator.")
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .listRowBackground(themeManager.cardBackground)
                    
                    // Manage Exercises Section
                    Section {
                        ForEach(WorkoutType.allCases.filter { $0 != .rest }, id: \.self) { type in
                            let filteredExercises = exercises.filter { $0.type == type }
                            
                            DisclosureGroup {
                                ForEach(filteredExercises) { exercise in
                                    NavigationLink {
                                        ExerciseMuscleEditorView(exercise: exercise)
                                            .environmentObject(themeManager)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name)
                                                    .foregroundColor(themeManager.primaryText)
                                                Text(exercise.targetMuscles.map(\.displayName).sorted().joined(separator: ", "))
                                                    .font(.caption)
                                                    .foregroundColor(themeManager.secondaryText)
                                                    .lineLimit(1)
                                            }

                                            if exercise.isCardio {
                                                Spacer()
                                                Image(systemName: "figure.run").foregroundColor(.orange)
                                            }
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

                        Button(action: { showingCSVImporter = true }) {
                            Label("Import Data from CSV", systemImage: "square.and.arrow.down")
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
            .dismissableKeyboard()
            .sheet(isPresented: $showingAddExercise) {
                addExerciseSheet
                    .fontDesign(themeManager.selectedFont.design)
            }
            .sheet(isPresented: $showingAddHistoricalWorkout) {
                AddHistoricalWorkoutView()
                    .environmentObject(themeManager)
            }
            .sheet(item: $exportURL) { url in
                ShareSheet(activityItems: [url])
            }
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                importCSV(from: result)
            }
            .alert("CSV Import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .preferredColorScheme(themeManager.colorScheme)
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
        var csvString = "Date,Exercise,Type,IsCardio,Location,SetNumber,Reps,Weight(lbs),Difficulty,RestTime(s),SetNotes,MachineSettings,WarmUp(min),Run(min),CoolDown(min),Speed,Intensity,SessionNotes\n"

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
            let location = escapeCSV(session.location.rawValue)
            let settings = escapeCSV(session.machineSettings)
            let sessionNotes = escapeCSV(session.notes)

            if exercise.isCardio {
                let wUp   = session.warmUpTime.map    { String($0) } ?? ""
                let run   = session.runningTime.map   { String($0) } ?? ""
                let cDown = session.coolDownTime.map  { String($0) } ?? ""
                let speed = session.runningSpeed.map  { String($0) } ?? ""
                let intensity = session.intensityRating.map { String($0) } ?? ""

                csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),,,,,,,\(settings),\(wUp),\(run),\(cDown),\(speed),\(intensity),\(sessionNotes)\n")
            } else {
                let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }

                if sortedSets.isEmpty {
                    // Session exists but no sets logged
                    csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),,,,,,,\(settings),,,,,,\(sessionNotes)\n")
                } else {
                    for set in sortedSets {
                        let setNotes  = escapeCSV(set.notes)
                        let restTime  = set.restTimeSeconds.map { String($0) } ?? ""
                        csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),\(set.setNumber),\(set.reps),\(set.weight),\(set.difficulty),\(restTime),\(setNotes),\(settings),,,,,,\(sessionNotes)\n")
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

    private func importCSV(from result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let csvString = try String(contentsOf: url, encoding: .utf8)
            let summary = try importCSVString(csvString)
            try context.save()
            var message = "Imported \(summary.sessions) sessions, \(summary.sets) sets, and \(summary.weights) body weight entries."
            if summary.skipped > 0 {
                message += " Skipped \(summary.skipped) entries that were already in the app."
            }
            importMessage = message
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func importCSVString(_ csvString: String) throws -> (sessions: Int, sets: Int, weights: Int, skipped: Int) {
        let rows = parseCSVRows(csvString)
        var index = 0
        var sessionsImported = 0
        var setsImported = 0
        var weightsImported = 0
        var duplicatesSkipped = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Look up exercises against the live context (the view's @Query snapshot
        // doesn't refresh mid-import, which used to duplicate every exercise),
        // and remember what already exists so re-importing an export is a no-op.
        var exerciseCache: [String: Exercise] = [:]
        var existingSessionKeys = Set<String>()
        var existingWeightKeys = Set<String>()

        if let storedExercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in storedExercises {
                exerciseCache[exercise.name.lowercased()] = exercise
                for session in exercise.sessions {
                    existingSessionKeys.insert(sessionDedupKey(exerciseName: exercise.name, date: session.date))
                }
            }
        }
        if let storedWeights = try? context.fetch(FetchDescriptor<BodyWeightEntry>()) {
            for entry in storedWeights {
                existingWeightKeys.insert("\(entry.date.timeIntervalSince1970)|\(entry.weight)")
            }
        }

        while index < rows.count {
            let row = rows[index]
            if row.first == "Date", row.contains("Exercise") {
                let header = headerMap(row)
                index += 1
                var importedSessions: [String: ExerciseSession] = [:]

                while index < rows.count {
                    let workoutRow = rows[index]
                    if workoutRow.isEmpty || workoutRow.first == "Body Weight History" {
                        break
                    }
                    guard let dateText = value(in: workoutRow, header: header, column: "Date"),
                          let date = dateFormatter.date(from: dateText),
                          let exerciseName = value(in: workoutRow, header: header, column: "Exercise"),
                          !exerciseName.isEmpty,
                          let typeText = value(in: workoutRow, header: header, column: "Type") else {
                        index += 1
                        continue
                    }

                    // A session for this exercise at this exact time already
                    // exists in the app — skip the row instead of duplicating.
                    if existingSessionKeys.contains(sessionDedupKey(exerciseName: exerciseName, date: date)) {
                        duplicatesSkipped += 1
                        index += 1
                        continue
                    }

                    let workoutType = WorkoutType(rawValue: typeText) ?? .push
                    let isCardio = value(in: workoutRow, header: header, column: "IsCardio") == "Yes"
                    let exercise = findOrCreateExercise(named: exerciseName, type: workoutType, isCardio: isCardio, cache: &exerciseCache)
                    let locationText = value(in: workoutRow, header: header, column: "Location") ?? WorkoutLocation.planetFitness.rawValue
                    let location = WorkoutLocation(rawValue: locationText) ?? .planetFitness
                    let machineSettings = value(in: workoutRow, header: header, column: "MachineSettings") ?? ""
                    let sessionNotes = value(in: workoutRow, header: header, column: "SessionNotes") ?? ""
                    let sessionKey = "\(date.timeIntervalSince1970)-\(exerciseName.lowercased())-\(machineSettings)-\(sessionNotes)"
                    let session = importedSessions[sessionKey] ?? {
                        let newSession = ExerciseSession(
                            date: date,
                            machineSettings: machineSettings,
                            totalSets: 0,
                            notes: sessionNotes,
                            location: location,
                            warmUpTime: doubleValue(in: workoutRow, header: header, column: "WarmUp(min)"),
                            runningTime: doubleValue(in: workoutRow, header: header, column: "Run(min)"),
                            coolDownTime: doubleValue(in: workoutRow, header: header, column: "CoolDown(min)"),
                            runningSpeed: doubleValue(in: workoutRow, header: header, column: "Speed"),
                            intensityRating: intValue(in: workoutRow, header: header, column: "Intensity")
                        )
                        context.insert(newSession)
                        newSession.exercise = exercise
                        importedSessions[sessionKey] = newSession
                        sessionsImported += 1
                        return newSession
                    }()

                    if let setNumber = intValue(in: workoutRow, header: header, column: "SetNumber") {
                        let loggedSet = LoggedSet(
                            setNumber: setNumber,
                            reps: intValue(in: workoutRow, header: header, column: "Reps") ?? 0,
                            weight: doubleValue(in: workoutRow, header: header, column: "Weight(lbs)") ?? 0,
                            notes: value(in: workoutRow, header: header, column: "SetNotes") ?? "",
                            difficulty: intValue(in: workoutRow, header: header, column: "Difficulty") ?? 3,
                            restTimeSeconds: intValue(in: workoutRow, header: header, column: "RestTime(s)")
                        )
                        context.insert(loggedSet)
                        loggedSet.session = session
                        session.totalSets += 1
                        setsImported += 1
                    }

                    index += 1
                }
            } else if row.first == "Date", row.contains("Weight(lbs)") {
                let header = headerMap(row)
                index += 1

                while index < rows.count {
                    let weightRow = rows[index]
                    guard !weightRow.isEmpty else {
                        index += 1
                        continue
                    }

                    guard let dateText = value(in: weightRow, header: header, column: "Date"),
                          let date = dateFormatter.date(from: dateText),
                          let weight = doubleValue(in: weightRow, header: header, column: "Weight(lbs)") else {
                        break
                    }

                    let weightKey = "\(date.timeIntervalSince1970)|\(weight)"
                    if existingWeightKeys.contains(weightKey) {
                        duplicatesSkipped += 1
                        index += 1
                        continue
                    }

                    let entry = BodyWeightEntry(
                        date: date,
                        weight: weight,
                        notes: value(in: weightRow, header: header, column: "Notes") ?? ""
                    )
                    context.insert(entry)
                    existingWeightKeys.insert(weightKey)
                    weightsImported += 1
                    index += 1
                }
            } else {
                index += 1
            }
        }

        return (sessionsImported, setsImported, weightsImported, duplicatesSkipped)
    }

    private func sessionDedupKey(exerciseName: String, date: Date) -> String {
        "\(exerciseName.lowercased())|\(date.timeIntervalSince1970)"
    }

    private func findOrCreateExercise(named name: String, type: WorkoutType, isCardio: Bool, cache: inout [String: Exercise]) -> Exercise {
        if let existing = cache[name.lowercased()] {
            existing.isCardio = isCardio
            existing.type = type
            return existing
        }

        let exercise = Exercise(name: name, type: type, isCardio: isCardio)
        context.insert(exercise)
        cache[name.lowercased()] = exercise
        return exercise
    }

    private func headerMap(_ row: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: row.enumerated().map { ($0.element, $0.offset) })
    }

    private func value(in row: [String], header: [String: Int], column: String) -> String? {
        guard let index = header[column], row.indices.contains(index) else { return nil }
        let value = row[index]
        return value.isEmpty ? nil : value
    }

    private func intValue(in row: [String], header: [String: Int], column: String) -> Int? {
        value(in: row, header: header, column: column).flatMap(Int.init)
    }

    private func doubleValue(in row: [String], header: [String: Int], column: String) -> Double? {
        value(in: row, header: header, column: column).flatMap(Double.init)
    }

    private func parseCSVRows(_ csvString: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var iterator = csvString.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isInsideQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append(next)
                    } else {
                        isInsideQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !isInsideQuotes {
                row.append(field)
                if row.contains(where: { !$0.isEmpty }) {
                    rows.append(row)
                } else {
                    rows.append([])
                }
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}

struct ExerciseMuscleEditorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise
    @State private var selectedMuscles: Set<TargetMuscle> = []

    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name)
                            .appHeadingStyle()
                            .foregroundColor(themeManager.primaryText)
                        Text("Tap muscles on the diagram to define what this exercise targets.")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }

                    MuscleDiagramView(
                        activatedMuscles: selectedMuscles,
                        restingMuscles: [],
                        selectedMuscles: $selectedMuscles,
                        isEditable: true
                    )
                    .environmentObject(themeManager)
                    .padding()
                    .appCard()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Muscles")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryText)
                        Text("Tap to toggle. Some muscles (like lats or cardio) can only be selected here.")
                            .font(.caption)
                            .foregroundColor(themeManager.secondaryText)

                        FlexibleMuscleTagView(selectedMuscles: $selectedMuscles, themeManager: themeManager)
                    }
                    .padding()
                    .appCard()

                    Button(action: saveTargets) {
                        Text("Save Muscle Targets")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appAccent)
                            .cornerRadius(14)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Muscle Targets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedMuscles = exercise.targetMuscles
        }
        .preferredColorScheme(themeManager.colorScheme)
    }

    private func saveTargets() {
        exercise.targetMuscles = selectedMuscles
        try? context.save()
        dismiss()
    }
}

struct FlexibleMuscleTagView: View {
    @Binding var selectedMuscles: Set<TargetMuscle>
    let themeManager: ThemeManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(TargetMuscle.allCases.sorted { $0.displayName < $1.displayName }) { muscle in
                let isSelected = selectedMuscles.contains(muscle)
                Button {
                    if isSelected {
                        selectedMuscles.remove(muscle)
                    } else {
                        selectedMuscles.insert(muscle)
                    }
                } label: {
                    Text(muscle.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : themeManager.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? Color(red: 0.85, green: 0.15, blue: 0.15) : themeManager.inputBackground)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
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
    @State private var selectedLocation: WorkoutLocation = .planetFitness
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
                                .font(.headline)
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
                                .font(.headline)
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

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workout Location")
                                .font(.headline)
                                .foregroundColor(themeManager.secondaryText)

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
                                .font(.headline)
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
                                .font(.headline)
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
            .dismissableKeyboard()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
            .fontDesign(themeManager.selectedFont.design)
        }
    }
    
    var cardioInputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cardio Metrics")
                .font(.headline)
                .foregroundColor(themeManager.primaryText)
            
            HStack(spacing: 15) {
                VStack(alignment: .leading) {
                    Text("Warm-up (min)")
                        .font(.caption)
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
                        .font(.caption)
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
                        .font(.caption)
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
                        .font(.caption)
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
                .font(.headline)
                .foregroundColor(themeManager.primaryText)
            
            // Machine Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Machine Settings")
                    .font(.caption)
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
                                    .font(.caption)
                            }
                        }
                    }
                    
                    HStack(spacing: 15) {
                        VStack(alignment: .leading) {
                            Text("Reps")
                                .font(.caption)
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
                                .font(.caption)
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
                            .font(.caption)
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
            location: selectedLocation,
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
                .font(.caption)
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
