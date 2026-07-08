import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weightEntries: [BodyWeightEntry]

    @AppStorage("restTargetSeconds") private var restTarget: Int = 90
    @AppStorage("legPressSledWeight") private var legPressSledWeight: Double = 167
    @AppStorage("progressPhotosEnabled") private var progressPhotosEnabled = true
    @AppStorage("progressPhotosLockEnabled") private var progressPhotosLockEnabled = false
    @AppStorage("progressPhotosPasswordHash") private var progressPhotosPasswordHash = ""

    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var importMessage: String?

    @State private var showingSetPassword = false
    @State private var showingRemovePassword = false
    @State private var showingWrongPassword = false
    @State private var passwordEntry = ""

    private let restOptions = [60, 90, 120, 180]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    trainingCard
                    appearanceCard
                    privacyCard
                    libraryCard
                    dataCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .dismissableKeyboard()
            .sheet(item: $exportURL) { url in
                ShareSheet(items: [url])
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                importCSV(from: result)
            }
            .alert(
                "CSV Import",
                isPresented: Binding(
                    get: { importMessage != nil },
                    set: { if !$0 { importMessage = nil } }
                )
            ) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    // MARK: - Training

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Training")

            VStack(alignment: .leading, spacing: 8) {
                Text("Rest timer")
                    .appBodyStyle()
                    .foregroundColor(themeManager.primaryText)
                Picker("Rest timer", selection: $restTarget) {
                    ForEach(restOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                Text("Countdown between sets during a live session.")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leg press sled")
                        .appBodyStyle()
                        .foregroundColor(themeManager.primaryText)
                    Text("Starting weight for plate math")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
                Spacer()
                TextField("167", value: $legPressSledWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .appInputStyle()
                Text("lb")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Appearance")

            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .appBodyStyle()
                    .foregroundColor(themeManager.primaryText)
                Picker("Theme", selection: $themeManager.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Font")
                    .appBodyStyle()
                    .foregroundColor(themeManager.primaryText)
                Picker("Font", selection: $themeManager.selectedFont) {
                    ForEach(AppFontChoice.allCases) { font in
                        Text(font.rawValue).tag(font)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Progress Photos")

            Toggle(isOn: $progressPhotosEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress photos")
                        .appBodyStyle()
                        .foregroundColor(themeManager.primaryText)
                    Text("Show the photo timeline on the Body tab")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .tint(.appAccent)

            if progressPhotosEnabled {
                Divider()

                Toggle(isOn: lockToggleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock behind password")
                            .appBodyStyle()
                            .foregroundColor(themeManager.primaryText)
                        Text(progressPhotosLockEnabled
                             ? "Photos stay hidden until you enter it"
                             : "Keep photos out of sight when someone borrows your phone")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                }
                .tint(.appAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .alert("Set Photo Password", isPresented: $showingSetPassword) {
            SecureField("Password", text: $passwordEntry)
            Button("Set Password") {
                let trimmed = passwordEntry.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    progressPhotosPasswordHash = PasscodeHasher.hash(trimmed)
                    progressPhotosLockEnabled = true
                }
                passwordEntry = ""
            }
            Button("Cancel", role: .cancel) { passwordEntry = "" }
        } message: {
            Text("You'll need this password to see your progress photos or turn the lock off. There is no recovery if you forget it.")
        }
        .alert("Enter Password to Remove Lock", isPresented: $showingRemovePassword) {
            SecureField("Password", text: $passwordEntry)
            Button("Remove Lock", role: .destructive) {
                if PasscodeHasher.hash(passwordEntry.trimmingCharacters(in: .whitespaces)) == progressPhotosPasswordHash {
                    progressPhotosLockEnabled = false
                    progressPhotosPasswordHash = ""
                } else {
                    showingWrongPassword = true
                }
                passwordEntry = ""
            }
            Button("Cancel", role: .cancel) { passwordEntry = "" }
        }
        .alert("Wrong Password", isPresented: $showingWrongPassword) {
            Button("OK") {}
        } message: {
            Text("The photo lock stays on.")
        }
    }

    /// Turning the lock on routes through set-a-password; turning it off
    /// requires the current password first.
    private var lockToggleBinding: Binding<Bool> {
        Binding(
            get: { progressPhotosLockEnabled },
            set: { wantsOn in
                if wantsOn {
                    showingSetPassword = true
                } else {
                    showingRemovePassword = true
                }
            }
        )
    }

    // MARK: - Library

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionKicker(text: "Library")
                .padding(.bottom, 8)

            NavigationLink {
                ManageExercisesView()
            } label: {
                settingsRow(icon: "dumbbell.fill", color: .appAccent,
                            title: "Manage Exercises",
                            subtitle: "Add, remove, and edit muscle targets")
            }
            Divider()
            NavigationLink {
                AddHistoricalWorkoutView()
            } label: {
                settingsRow(icon: "clock.arrow.circlepath", color: .appCardio,
                            title: "Log Past Workout",
                            subtitle: "Back-date a session you forgot to track")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Data

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionKicker(text: "Data")
                .padding(.bottom, 8)

            Button {
                exportToCSV()
            } label: {
                settingsRow(icon: "square.and.arrow.up", color: .appSuccess,
                            title: "Export CSV",
                            subtitle: "All workouts and body weight history")
            }
            Divider()
            Button {
                showingImporter = true
            } label: {
                settingsRow(icon: "square.and.arrow.down", color: .appWarning,
                            title: "Import CSV",
                            subtitle: "Duplicates are skipped automatically")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func settingsRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appBodyStyle()
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryText)
                Text(subtitle)
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.secondaryText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - CSV export

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

        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "WorkoutData_\(fileFormatter.string(from: Date())).csv"

        do {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
        } catch {
            importMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func escapeCSV(_ string: String) -> String {
        var result = string.replacingOccurrences(of: "\"", with: "\"\"")
        if result.contains(",") || result.contains("\n") || result.contains("\"") {
            result = "\"\(result)\""
        }
        return result
    }

    // MARK: - CSV import

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
                exerciseCache["\(exercise.name.lowercased())|\(exercise.location.rawValue)"] = exercise
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

                    if existingSessionKeys.contains(sessionDedupKey(exerciseName: exerciseName, date: date)) {
                        duplicatesSkipped += 1
                        index += 1
                        continue
                    }

                    let workoutType = WorkoutType(rawValue: typeText) ?? .push
                    let isCardio = value(in: workoutRow, header: header, column: "IsCardio") == "Yes"
                    let locationText = value(in: workoutRow, header: header, column: "Location") ?? WorkoutLocation.gym.rawValue
                    let location = WorkoutLocation.from(stored: locationText)
                    let exercise = findOrCreateExercise(named: exerciseName, type: workoutType, isCardio: isCardio, location: location, cache: &exerciseCache)
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

    private func findOrCreateExercise(named name: String, type: WorkoutType, isCardio: Bool, location: WorkoutLocation, cache: inout [String: Exercise]) -> Exercise {
        // Home and gym libraries are separate, so the same name can exist
        // once per location.
        let key = "\(name.lowercased())|\(location.rawValue)"
        if let existing = cache[key] {
            existing.isCardio = isCardio
            existing.type = type
            return existing
        }

        let exercise = Exercise(name: name, type: type, isCardio: isCardio, location: location)
        context.insert(exercise)
        cache[key] = exercise
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

// MARK: - Manage exercises

struct ManageExercisesView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newType: WorkoutType = .push
    @State private var newIsCardio = false
    @State private var newLocation: WorkoutLocation = .gym
    @State private var exerciseToDelete: Exercise?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(WorkoutLocation.allCases) { location in
                    let atLocation = exercises.filter { $0.location == location }
                    if !atLocation.isEmpty {
                        Label(location.rawValue, systemImage: location.icon)
                            .appHeadingStyle()
                            .foregroundColor(themeManager.primaryText)
                            .padding(.top, 4)
                    }
                    ForEach([WorkoutType.push, .pull, .legs], id: \.self) { type in
                        let group = atLocation.filter { $0.type == type }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionKicker(text: "\(type.rawValue) · \(group.count)")
                                    .padding(.bottom, 8)
                                ForEach(group, id: \.persistentModelID) { exercise in
                                    NavigationLink {
                                        ExerciseMuscleEditorView(exercise: exercise)
                                    } label: {
                                        exerciseRow(exercise)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            exerciseToDelete = exercise
                                        } label: {
                                            Label("Delete Exercise", systemImage: "trash")
                                        }
                                    }
                                    if exercise.persistentModelID != group.last?.persistentModelID {
                                        Divider()
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appCard()
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            addSheet
                .themedPresentation()
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Delete \(exerciseToDelete?.name ?? "exercise")?",
            isPresented: Binding(
                get: { exerciseToDelete != nil },
                set: { if !$0 { exerciseToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let exercise = exerciseToDelete {
                    context.delete(exercise)
                    try? context.save()
                }
                exerciseToDelete = nil
            }
            Button("Cancel", role: .cancel) { exerciseToDelete = nil }
        } message: {
            Text("This also deletes all its logged history.")
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.isCardio ? "figure.run" : "dumbbell.fill")
                .font(.system(size: 14))
                .foregroundColor(.appAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .appBodyStyle()
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryText)
                Text(exercise.targetMuscles.map(\.displayName).sorted().joined(separator: ", "))
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeManager.secondaryText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var addSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Exercise name", text: $newName)
                    .appInputStyle()

                Picker("Day", selection: $newType) {
                    ForEach([WorkoutType.push, .pull, .legs], id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Location", selection: $newLocation) {
                    ForEach(WorkoutLocation.allCases) { loc in
                        Text(loc.rawValue).tag(loc)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Cardio exercise", isOn: $newIsCardio)
                    .tint(.appAccent)
                    .padding(12)
                    .background(themeManager.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Add Exercise") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    context.insert(Exercise(name: trimmed, type: newType, isCardio: newIsCardio, location: newLocation))
                    try? context.save()
                    newName = ""
                    newIsCardio = false
                    showingAdd = false
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAdd = false }
                }
            }
        }
    }
}

// MARK: - Muscle target editor

struct ExerciseMuscleEditorView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selection: Set<TargetMuscle> = []
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Tap Muscles on the Body")
                    MuscleDiagramView(
                        selectedMuscles: $selection,
                        isEditable: true
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .appCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Or Toggle Tags")
                    let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(TargetMuscle.allCases) { muscle in
                            let isOn = selection.contains(muscle)
                            Button {
                                if isOn {
                                    selection.remove(muscle)
                                } else {
                                    selection.insert(muscle)
                                }
                            } label: {
                                Text(muscle.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(isOn ? .white : themeManager.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isOn ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(themeManager.inputBackground))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            selection = exercise.targetMuscles
            loaded = true
        }
        .onDisappear {
            exercise.targetMuscles = selection
            try? context.save()
        }
    }
}

// MARK: - Historical workout

struct AddHistoricalWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var date = Date()
    @State private var selectedExercise: Exercise?
    @State private var location: WorkoutLocation = .gym
    @State private var notes = ""

    struct HistoricalSet: Identifiable {
        let id = UUID()
        var reps = 8
        var weight: Double? = nil
        var difficulty = 3
    }
    @State private var sets: [HistoricalSet] = [HistoricalSet()]

    // Cardio
    @State private var warmUpTime = ""
    @State private var runningTime = ""
    @State private var coolDownTime = ""
    @State private var runningSpeed = ""
    @State private var intensity = 5.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionKicker(text: "When & What")

                    DatePicker("Date", selection: $date, in: ...Date())
                        .tint(.appAccent)
                        .foregroundColor(themeManager.primaryText)

                    HStack {
                        Text("Exercise")
                            .appBodyStyle()
                            .foregroundColor(themeManager.primaryText)
                        Spacer()
                        Menu {
                            ForEach(WorkoutLocation.allCases) { loc in
                                Section(loc.rawValue) {
                                    ForEach(exercises.filter { $0.location == loc }, id: \.persistentModelID) { exercise in
                                        Button(exercise.name) {
                                            selectedExercise = exercise
                                            location = exercise.location
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedExercise?.name ?? "Choose")
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appAccent)
                        }
                    }

                    if let selected = selectedExercise {
                        ChipLabel(text: selected.location.rawValue, color: .appCardio)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                if selectedExercise?.isCardio == true {
                    cardioCard
                } else if selectedExercise != nil {
                    setsCard
                }

                if selectedExercise != nil {
                    TextField("Session notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .appInputStyle()

                    Button("Save Workout") { save() }
                        .buttonStyle(EmberButtonStyle())
                }
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle("Log Past Workout")
        .navigationBarTitleDisplayMode(.inline)
        .dismissableKeyboard()
    }

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Sets")
            ForEach($sets) { $set in
                HStack(spacing: 10) {
                    Stepper(value: $set.reps, in: 1...50) {
                        Text("\(set.reps) reps")
                            .appBodyStyle()
                            .foregroundColor(themeManager.primaryText)
                    }
                    .fixedSize()
                    TextField("lb", value: $set.weight, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(width: 64)
                        .appInputStyle()
                    DifficultyDots(rating: set.difficulty, size: 12, interactive: true) { tapped in
                        set.difficulty = tapped
                    }
                }
            }
            HStack {
                Button {
                    sets.append(HistoricalSet(weight: sets.last?.weight))
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                }
                .buttonStyle(QuietButtonStyle())
                if sets.count > 1 {
                    Button {
                        sets.removeLast()
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var cardioCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Cardio")
            HStack(spacing: 10) {
                historicalField("Warm-up", text: $warmUpTime)
                historicalField("Run", text: $runningTime)
                historicalField("Cool-down", text: $coolDownTime)
            }
            historicalField("Speed (mph)", text: $runningSpeed)
            HStack {
                Text("Intensity")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
                Slider(value: $intensity, in: 1...10, step: 1)
                    .tint(.appAccent)
                Text("\(Int(intensity))/10")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.appAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func historicalField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .appInputStyle()
        }
    }

    private func save() {
        guard let exercise = selectedExercise else { return }

        let isCardio = exercise.isCardio
        let session = ExerciseSession(
            date: date,
            machineSettings: "",
            totalSets: isCardio ? 0 : sets.count,
            notes: notes,
            location: location,
            warmUpTime: isCardio ? Double(warmUpTime) : nil,
            runningTime: isCardio ? Double(runningTime) : nil,
            coolDownTime: isCardio ? Double(coolDownTime) : nil,
            runningSpeed: isCardio ? Double(runningSpeed) : nil,
            intensityRating: isCardio ? Int(intensity) : nil
        )
        context.insert(session)
        session.exercise = exercise

        if !isCardio {
            for (index, historical) in sets.enumerated() {
                let set = LoggedSet(
                    setNumber: index + 1,
                    reps: historical.reps,
                    weight: historical.weight ?? 0,
                    difficulty: historical.difficulty
                )
                context.insert(set)
                set.session = session
            }
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
