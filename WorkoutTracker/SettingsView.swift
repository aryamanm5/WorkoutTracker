import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("restTargetSeconds") private var restTarget: Int = 90
    @AppStorage("trainingGoal") private var trainingGoal: TrainingEngine.TrainingGoal = .hypertrophy
    @AppStorage("legPressSledWeight") private var legPressSledWeight: Double = 167
    @AppStorage("progressPhotosEnabled") private var progressPhotosEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
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
            .background(Color.appBackground.ignoresSafeArea())
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
                Text("Coach goal")
                    .appBodyStyle()
                    .foregroundColor(Color.appPrimaryText)
                Picker("Coach goal", selection: $trainingGoal) {
                    ForEach(TrainingEngine.TrainingGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: trainingGoal) { Haptics.shared.play(.selection) }
                Text(trainingGoal == .hypertrophy
                     ? "Adds weight once every set hits 12 reps in the 8–12 range."
                     : "Adds weight every session you finish all sets at 5+ reps.")
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Rest timer")
                    .appBodyStyle()
                    .foregroundColor(Color.appPrimaryText)
                Picker("Rest timer", selection: $restTarget) {
                    ForEach(restOptions, id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: restTarget) { Haptics.shared.play(.selection) }
                Text("Countdown between sets during a live session.")
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leg press sled")
                        .appBodyStyle()
                        .foregroundColor(Color.appPrimaryText)
                    Text("Starting weight for plate math")
                        .appCaptionStyle()
                        .foregroundColor(Color.appSecondaryText)
                }
                Spacer()
                TextField("167", value: $legPressSledWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .appInputStyle()
                Text("lb")
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
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
                Text("Dark Mode")
                    .appBodyStyle()
                    .foregroundColor(Color.appPrimaryText)
                Picker("Dark Mode", selection: $themeManager.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: themeManager.appearance) { Haptics.shared.play(.selection) }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .appBodyStyle()
                    .foregroundColor(Color.appPrimaryText)
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        themeSwatch(theme)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Font")
                    .appBodyStyle()
                    .foregroundColor(Color.appPrimaryText)
                Picker("Font", selection: $themeManager.selectedFont) {
                    ForEach(AppFontChoice.allCases) { font in
                        Text(font.rawValue).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: themeManager.selectedFont) { Haptics.shared.play(.selection) }
            }

            Divider()

            Toggle(isOn: $hapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptics")
                        .appBodyStyle()
                        .foregroundColor(Color.appPrimaryText)
                    Text("Taps on buttons, and a celebration when you finish")
                        .appCaptionStyle()
                        .foregroundColor(Color.appSecondaryText)
                }
            }
            .tint(.appAccent)
            .onChange(of: hapticsEnabled) { _, enabled in
                guard enabled else { return }
                // The engine is torn down while off; bring it back and show off
                // what was just switched on.
                Haptics.shared.prepare()
                Haptics.shared.play(.exerciseComplete)
            }

            if hapticsEnabled {
                Button("Feel a workout celebration") {
                    Haptics.shared.play(.workoutLegendary)
                }
                .buttonStyle(QuietButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    /// Tappable color chip; selecting one instantly re-themes the whole app.
    private func themeSwatch(_ theme: AppTheme) -> some View {
        let selected = themeManager.theme == theme
        return Button {
            themeManager.theme = theme
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(theme.swatchGradient)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle().stroke(Color.appPrimaryText, lineWidth: selected ? 2.5 : 0)
                            .padding(-3)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                            .opacity(selected ? 1 : 0)
                    )
                Text(theme.displayName)
                    .font(.system(size: 11, weight: selected ? .bold : .medium))
                    .foregroundColor(selected ? Color.appPrimaryText : Color.appSecondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .hapticButton(.selection, pressScale: 0.92)
    }

    // MARK: - Privacy

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Progress Photos")

            Toggle(isOn: $progressPhotosEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress photos")
                        .appBodyStyle()
                        .foregroundColor(Color.appPrimaryText)
                    Text("Show the photo timeline on the Body tab")
                        .appCaptionStyle()
                        .foregroundColor(Color.appSecondaryText)
                }
            }
            .tint(.appAccent)
            .onChange(of: progressPhotosEnabled) { _, on in
                Haptics.shared.play(on ? .toggleOn : .toggleOff)
            }

            if progressPhotosEnabled {
                Divider()

                Toggle(isOn: lockToggleBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lock behind password")
                            .appBodyStyle()
                            .foregroundColor(Color.appPrimaryText)
                        Text(progressPhotosLockEnabled
                             ? "Photos stay hidden until you enter it"
                             : "Keep photos out of sight when someone borrows your phone")
                            .appCaptionStyle()
                            .foregroundColor(Color.appSecondaryText)
                    }
                }
                .tint(.appAccent)
                .onChange(of: progressPhotosLockEnabled) { _, on in
                    Haptics.shared.play(on ? .toggleOn : .toggleOff)
                }
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
            Text("You'll need this password to see your progress photos or turn the lock off. If you forget it, you can reset it with Face ID or your device passcode.")
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
            Button("Forgot Password?") {
                passwordEntry = ""
                PasscodeHasher.recoverWithDeviceAuth {
                    progressPhotosLockEnabled = false
                    progressPhotosPasswordHash = ""
                }
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
            .hapticRow()
            Divider()
            NavigationLink {
                AddHistoricalWorkoutView()
            } label: {
                settingsRow(icon: "clock.arrow.circlepath", color: .appCardio,
                            title: "Log Past Workout",
                            subtitle: "Back-date a session you forgot to track")
            }
            .hapticRow()
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
                            subtitle: "Workouts, measurements, and body weight")
            }
            .hapticRow()
            Divider()
            Button {
                showingImporter = true
            } label: {
                settingsRow(icon: "square.and.arrow.down", color: .appWarning,
                            title: "Import CSV",
                            subtitle: "Duplicates are skipped automatically")
            }
            .hapticRow()
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
                    .foregroundColor(Color.appPrimaryText)
                Text(subtitle)
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.appSecondaryText)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - CSV export / import

    private func exportToCSV() {
        let csvString = WorkoutCSV(context: context).exportString()

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
            let summary = WorkoutCSV(context: context).importString(csvString)
            try context.save()
            var message = "Imported \(summary.sessions) sessions, \(summary.sets) sets, \(summary.measurements) measurements, and \(summary.weights) body weight entries."
            if summary.skipped > 0 {
                message += " Skipped \(summary.skipped) entries that were already in the app."
            }
            importMessage = message
        } catch {
            importMessage = "Import failed: \(error.localizedDescription)"
        }
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
                            .foregroundColor(Color.appPrimaryText)
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
                                    .hapticRow()
                                    .contextMenu {
                                        let other: WorkoutLocation = exercise.location == .home ? .gym : .home
                                        Button {
                                            exercise.location = other
                                            try? context.save()
                                            Haptics.shared.play(.selection)
                                        } label: {
                                            Label("Move to \(other.rawValue)", systemImage: other.icon)
                                        }
                                        Button {
                                            duplicate(exercise, to: other)
                                        } label: {
                                            Label("Copy to \(other.rawValue)", systemImage: "plus.square.on.square")
                                        }
                                        Divider()
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
        .background(Color.appBackground.ignoresSafeArea())
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
        .deleteConfirmation("Delete \(exerciseToDelete?.name ?? "exercise")?", item: $exerciseToDelete, context: context) { _ in
            "This also deletes all its logged history."
        }
    }

    /// A separate exercise at the other location: same name, type, and muscle
    /// targets, but its own history — home and gym weights and machine
    /// settings differ, so they must never share progression data.
    private func duplicate(_ exercise: Exercise, to location: WorkoutLocation) {
        let copy = Exercise(
            name: exercise.name,
            type: exercise.type,
            isCardio: exercise.isCardio,
            location: location
        )
        copy.targetMuscleRawValues = exercise.targetMuscleRawValues
        context.insert(copy)
        try? context.save()
        Haptics.shared.play(.setLogged)
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
                    .foregroundColor(Color.appPrimaryText)
                Text(exercise.targetMuscles.map(\.displayName).sorted().joined(separator: ", "))
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.appSecondaryText)
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
                    .background(Color.appInputBackground)
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
            .background(Color.appBackground.ignoresSafeArea())
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
    @State private var copyCreated = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                locationCard

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
                                    .foregroundColor(isOn ? .white : Color.appPrimaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isOn ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(Color.appInputBackground))
                                    .clipShape(Capsule())
                            }
                            .hapticButton(isOn ? .toggleOff : .toggleOn, pressScale: 0.94)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
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

    /// Where this exercise lives. Moving it re-homes the exercise and all its
    /// history; the copy button instead creates an independent twin at the
    /// other location, since home and gym weights aren't interchangeable.
    private var locationCard: some View {
        let other: WorkoutLocation = exercise.location == .home ? .gym : .home
        return VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Location")

            Picker("Location", selection: Binding(
                get: { exercise.location },
                set: {
                    exercise.location = $0
                    try? context.save()
                }
            )) {
                ForEach(WorkoutLocation.allCases) { loc in
                    Text(loc.rawValue).tag(loc)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: exercise.location) { Haptics.shared.play(.selection) }

            Text("Sessions only offer exercises from the location you're training at. Moving keeps this exercise's history.")
                .appCaptionStyle()
                .foregroundColor(Color.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                let copy = Exercise(
                    name: exercise.name,
                    type: exercise.type,
                    isCardio: exercise.isCardio,
                    location: other
                )
                copy.targetMuscleRawValues = exercise.targetMuscleRawValues
                context.insert(copy)
                try? context.save()
                Haptics.shared.play(.setLogged)
                copyCreated = true
            } label: {
                Label(copyCreated ? "Copy created ✓" : "Create a copy at \(other.rawValue)",
                      systemImage: copyCreated ? "checkmark.circle.fill" : "plus.square.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(copyCreated)

            Text("A copy tracks its own weights and settings — e.g. a home dumbbell press separate from the gym one.")
                .appCaptionStyle()
                .foregroundColor(Color.appSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
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
                        .foregroundColor(Color.appPrimaryText)

                    HStack {
                        Text("Exercise")
                            .appBodyStyle()
                            .foregroundColor(Color.appPrimaryText)
                        Spacer()
                        Menu {
                            ForEach(WorkoutLocation.allCases) { loc in
                                Section(loc.rawValue) {
                                    ForEach(exercises.filter { $0.location == loc }, id: \.persistentModelID) { exercise in
                                        Button(exercise.name) {
                                            selectedExercise = exercise
                                            location = exercise.location
                                            Haptics.shared.play(.selection)
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
        .background(Color.appBackground.ignoresSafeArea())
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
                            .foregroundColor(Color.appPrimaryText)
                    }
                    .fixedSize()
                    .onChange(of: set.reps) { Haptics.shared.play(.tap) }
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
                    .foregroundColor(Color.appSecondaryText)
                Slider(value: $intensity, in: 1...10, step: 1)
                    .tint(.appAccent)
                    .onChange(of: intensity) { Haptics.shared.play(.detent) }
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
                .foregroundColor(Color.appSecondaryText)
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
            warmUpTime: isCardio ? Double(userInput: warmUpTime) : nil,
            runningTime: isCardio ? Double(userInput: runningTime) : nil,
            coolDownTime: isCardio ? Double(userInput: coolDownTime) : nil,
            runningSpeed: isCardio ? Double(userInput: runningSpeed) : nil,
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
