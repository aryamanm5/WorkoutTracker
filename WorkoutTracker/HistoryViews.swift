import SwiftUI
import SwiftData

// MARK: - Day detail

/// Everything logged on one calendar day, reached from the heat calendar.
struct DayDetailView: View {
    let date: Date

    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \ExerciseSession.date) private var allSessions: [ExerciseSession]

    @State private var sessionToDelete: ExerciseSession?

    private var sessions: [ExerciseSession] {
        allSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if sessions.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 36))
                            .foregroundColor(themeManager.secondaryText)
                        Text("Rest day — nothing logged.")
                            .appBodyStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    metricsRow

                    ForEach(sessions, id: \.persistentModelID) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionCard(session: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("Delete Session", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this session?",
            isPresented: Binding(
                get: { sessionToDelete != nil },
                set: { if !$0 { sessionToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    context.delete(session)
                    try? context.save()
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
        } message: {
            Text("This removes \(sessionToDelete?.exercise?.name ?? "the session") and all its sets.")
        }
    }

    private var metricsRow: some View {
        let strength = sessions.filter { $0.exercise?.isCardio != true }
        let cardio = sessions.filter { $0.exercise?.isCardio == true }
        let sets = strength.reduce(0) { $0 + $1.sets.count }

        return HStack(spacing: 12) {
            StatTile(icon: "dumbbell.fill", iconColor: .appAccent, value: "\(strength.count)", label: "Strength")
            StatTile(icon: "figure.run", iconColor: .appCardio, value: "\(cardio.count)", label: "Cardio")
            StatTile(icon: "square.stack.3d.up.fill", iconColor: .appSuccess,
                     value: "\(sets)", label: "Sets")
        }
    }
}

// MARK: - Session card

struct SessionCard: View {
    let session: ExerciseSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.exercise?.isCardio == true ? "figure.run" : "dumbbell.fill")
                .font(.system(size: 18))
                .foregroundColor(session.exercise?.isCardio == true ? .appCardio : .appAccent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.exercise?.name ?? "Unknown")
                        .appBodyStyle()
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.primaryText)
                    if TrainingEngine.isPersonalRecord(session) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appWarning)
                    }
                }
                Text(subtitle)
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(session.date.formatted(date: .omitted, time: .shortened))
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(14)
        .appCard()
    }

    private var subtitle: String {
        if session.exercise?.isCardio == true {
            if let time = session.runningTime {
                return "\(TrainingEngine.formatWeight(time)) min run"
            }
            return "Cardio session"
        }
        let sets = session.sets.count
        if let top = session.sets.map(\.weight).max(), top > 0 {
            return "\(sets) set\(sets == 1 ? "" : "s") · top \(TrainingEngine.formatWeight(top)) lb"
        }
        return "\(sets) set\(sets == 1 ? "" : "s")"
    }
}

// MARK: - Session detail

struct SessionDetailView: View {
    let session: ExerciseSession
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if session.exercise?.isCardio == true {
                    cardioCard
                } else {
                    setsCard
                }

                if !session.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionKicker(text: "Notes")
                        Text(session.notes)
                            .appBodyStyle()
                            .foregroundColor(themeManager.primaryText)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                }
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(session.exercise?.name ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Edit") {
                    EditSessionView(session: session)
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.date.formatted(date: .complete, time: .shortened))
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                    HStack(spacing: 8) {
                        ChipLabel(text: session.location.rawValue, color: .appCardio)
                        if TrainingEngine.isPersonalRecord(session) {
                            ChipLabel(text: "PR 🏆", color: .appWarning)
                        }
                    }
                }
                Spacer()
            }
            if !session.machineSettings.isEmpty {
                Text("Machine: \(session.machineSettings)")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var setsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Sets")
            ForEach(session.sets.sorted { $0.setNumber < $1.setNumber }, id: \.persistentModelID) { set in
                VStack(alignment: .leading, spacing: 6) {
                    SetRow(number: set.setNumber, reps: set.reps, weight: set.weight, difficulty: set.difficulty)
                    HStack(spacing: 10) {
                        if let rest = set.restTimeSeconds {
                            Label("\(rest)s rest", systemImage: "timer")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeManager.secondaryText)
                        }
                        if !set.notes.isEmpty {
                            Text(set.notes)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeManager.secondaryText)
                                .italic()
                        }
                    }
                    .padding(.leading, 38)
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
            cardioRow(label: "Warm-up", value: session.warmUpTime, unit: "min")
            cardioRow(label: "Run", value: session.runningTime, unit: "min")
            cardioRow(label: "Cool-down", value: session.coolDownTime, unit: "min")
            cardioRow(label: "Speed", value: session.runningSpeed, unit: "mph")
            if let intensity = session.intensityRating {
                HStack {
                    Text("Intensity")
                        .appBodyStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Spacer()
                    Text("\(intensity)/10")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    @ViewBuilder
    private func cardioRow(label: String, value: Double?, unit: String) -> some View {
        if let value, value > 0 {
            HStack {
                Text(label)
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
                Spacer()
                Text("\(TrainingEngine.formatWeight(value)) \(unit)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(themeManager.primaryText)
            }
        }
    }
}

// MARK: - Edit session

struct EditSessionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ExerciseSession

    @State private var machineSettings: String = ""
    @State private var sessionNotes: String = ""
    @State private var selectedLocation: WorkoutLocation = .gym
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
        ScrollView {
            VStack(spacing: 16) {
                if session.exercise?.isCardio == true {
                    editCardioInterface
                } else {
                    editStrengthInterface
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionKicker(text: "Location")
                    Picker("Workout Location", selection: $selectedLocation) {
                        ForEach(WorkoutLocation.allCases) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionKicker(text: "Session Notes")
                    TextField("Notes", text: $sessionNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .appInputStyle()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                Button("Save Changes", action: saveChanges)
                    .buttonStyle(EmberButtonStyle())
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle("Edit Session")
        .navigationBarTitleDisplayMode(.inline)
        .dismissableKeyboard()
        .onAppear(perform: loadSessionData)
    }

    private var editCardioInterface: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Cardio Metrics")

            HStack(spacing: 10) {
                editField("Warm-up (min)", value: $warmUpTime)
                editField("Run (min)", value: $runningTime)
            }
            HStack(spacing: 10) {
                editField("Cool-down (min)", value: $coolDownTime)
                editField("Speed (mph)", value: $runningSpeed)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Intensity")
                        .appBodyStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Spacer()
                    Text("\(Int(intensityRating))/10")
                        .fontWeight(.bold)
                        .foregroundColor(Color.appAccent)
                }
                Slider(value: $intensityRating, in: 1...10, step: 1)
                    .tint(.appAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func editField(_ label: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .appInputStyle()
        }
    }

    private var editStrengthInterface: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionKicker(text: "Machine Settings")
                TextField("e.g. Seat Position 4", text: $machineSettings)
                    .appInputStyle()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()

            ForEach($editedSets) { $set in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Set \(set.setNumber)")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.appAccent)
                        Spacer()
                        Button {
                            deleteSet(set)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.appDanger)
                        }
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reps")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.reps, format: .number)
                                .keyboardType(.numberPad)
                                .appInputStyle()
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weight")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                            TextField("0", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .appInputStyle()
                        }
                    }

                    HStack {
                        Text("Effort")
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                        Spacer()
                        DifficultyDots(rating: set.difficulty, size: 20, interactive: true) { newRating in
                            set.difficulty = newRating
                        }
                    }

                    TextField("Set notes…", text: $set.notes)
                        .appInputStyle()
                }
                .padding(16)
                .appCard()
            }

            Button {
                addNewSet()
            } label: {
                Label("Add Set", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(QuietButtonStyle())
        }
    }

    private func loadSessionData() {
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

    private func addNewSet() {
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

    private func deleteSet(_ set: EditableSet) {
        editedSets.removeAll { $0.id == set.id }
        for (index, _) in editedSets.enumerated() {
            editedSets[index].setNumber = index + 1
        }
    }

    private func saveChanges() {
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
