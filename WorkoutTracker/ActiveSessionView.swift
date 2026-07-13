import SwiftUI
import SwiftData

/// One live training session: an exercise queue for the day's focus, inline
/// set logging with an automatic countdown rest timer, PR celebrations, and
/// a closing summary. Each finished exercise is saved immediately, so
/// leaving mid-session never loses completed work.
struct ActiveSessionView: View {
    let focus: WorkoutType
    let location: WorkoutLocation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(WorkoutViewModel.self) private var viewModel

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var sessionStart = Date()
    @State private var extraExercises: [Exercise] = []
    @State private var loggedSessions: [ExerciseSession] = []
    @State private var prBannerText: String?
    @State private var showingPicker = false
    @State private var showingSummary = false
    @State private var showingEndConfirm = false

    private var queue: [Exercise] {
        var result = allExercises.filter { $0.type == focus && $0.location == location }
        for extra in extraExercises where !result.contains(where: { $0 === extra }) {
            result.append(extra)
        }
        return result.sorted {
            let doneA = viewModel.isExerciseCompletedToday($0)
            let doneB = viewModel.isExerciseCompletedToday($1)
            if doneA != doneB { return !doneA }
            return $0.name < $1.name
        }
    }

    private var completedCount: Int {
        queue.filter { viewModel.isExerciseCompletedToday($0) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sessionHeader

                    if let prBannerText {
                        PRBanner(text: prBannerText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ForEach(queue, id: \.persistentModelID) { exercise in
                        NavigationLink {
                            ExercisePreviewView(exercise: exercise, location: location) { session in
                                exerciseFinished(session)
                            }
                        } label: {
                            QueueRow(
                                exercise: exercise,
                                isDone: viewModel.isExerciseCompletedToday(exercise)
                            )
                        }
                        .hapticRow()
                    }

                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
                .padding(16)
                .padding(.bottom, 90)
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("\(focus.rawValue) · \(location.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if loggedSessions.isEmpty {
                            dismiss()
                        } else {
                            showingEndConfirm = true
                        }
                    }
                    .hapticButton(.tap, pressScale: 1)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if loggedSessions.isEmpty {
                        dismiss()
                    } else {
                        showingSummary = true
                    }
                } label: {
                    Text(loggedSessions.isEmpty ? "End Session" : "Finish Session")
                }
                .buttonStyle(EmberButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(themeManager.background.opacity(0.94))
            }
            .confirmationDialog("Wrap up this session?", isPresented: $showingEndConfirm, titleVisibility: .visible) {
                Button("Show Summary") { showingSummary = true }
                Button("Just Close", role: .destructive) { dismiss() }
                Button("Keep Training", role: .cancel) {}
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerSheet(focus: focus, location: location) { exercise in
                    extraExercises.append(exercise)
                }
                .themedPresentation()
            }
            .sheet(isPresented: $showingSummary) {
                SessionSummaryView(
                    focus: focus,
                    start: sessionStart,
                    sessions: loggedSessions,
                    onDone: { dismiss() }
                )
                .themedPresentation()
                .interactiveDismissDisabled()
            }
        }
    }

    private var sessionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                TimelineView(.periodic(from: sessionStart, by: 1)) { context in
                    Text(elapsedString(to: context.date))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(themeManager.primaryText)
                }
                Text("Session time")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(completedCount)/\(queue.count)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.appAccent)
                Text("Exercises done")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .appCard()
    }

    private func elapsedString(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(sessionStart)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func exerciseFinished(_ session: ExerciseSession) {
        loggedSessions.append(session)

        let isPR = TrainingEngine.isPersonalRecord(session)
        // The logger stays silent on finish so the celebration can be sized
        // here, where we know both the set count and whether it was a PR.
        Celebration.exercise(sets: session.sets.count, isPersonalRecord: isPR)

        if isPR, let name = session.exercise?.name {
            let e1rm = TrainingEngine.bestOneRepMax(in: session)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                prBannerText = "New \(name) PR — est. 1RM \(TrainingEngine.formatWeight(e1rm)) lb!"
            }
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { prBannerText = nil }
            }
        }
    }
}

// MARK: - Queue row

private struct QueueRow: View {
    let exercise: Exercise
    let isDone: Bool

    @EnvironmentObject var themeManager: ThemeManager

    private var advice: TrainingEngine.ProgressionAdvice? {
        TrainingEngine.progression(for: exercise)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isDone
                  ? "checkmark.circle.fill"
                  : (exercise.isCardio ? "figure.run" : "dumbbell.fill"))
                .font(.system(size: 20))
                .foregroundColor(isDone ? .appSuccess : .appAccent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .appBodyStyle()
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryText)
                    .strikethrough(isDone, color: themeManager.secondaryText)

                if let advice, !isDone {
                    HStack(spacing: 6) {
                        Image(systemName: adviceIcon(advice.kind))
                            .font(.system(size: 12))
                        Text("\(TrainingEngine.formatWeight(advice.weight)) lb")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(adviceColor(advice.kind))
                } else if isDone {
                    Text("Logged today")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.secondaryText)
        }
        .padding(14)
        .appCard()
        .opacity(isDone ? 0.65 : 1)
    }

    private func adviceIcon(_ kind: TrainingEngine.ProgressionKind) -> String {
        switch kind {
        case .increase: return "arrow.up.circle.fill"
        case .decrease: return "arrow.down.circle.fill"
        case .hold, .manual: return "equal.circle.fill"
        }
    }

    private func adviceColor(_ kind: TrainingEngine.ProgressionKind) -> Color {
        switch kind {
        case .increase: return .appSuccess
        case .decrease: return .appWarning
        case .hold, .manual: return themeManager.secondaryText
        }
    }
}

// MARK: - Exercise preview

/// The stop between the queue and the logger: last time's numbers and the
/// coach's call for today, so you know the plan before the first set.
struct ExercisePreviewView: View {
    let exercise: Exercise
    let location: WorkoutLocation
    var onFinished: (ExerciseSession) -> Void

    @EnvironmentObject var themeManager: ThemeManager

    /// Preview and logger share one navigation entry: starting swaps this
    /// view for the logger in place, so finishing pops straight to the queue.
    @State private var started = false

    /// The two most recent real sessions, newest first.
    private var recentSessions: [ExerciseSession] {
        Array(exercise.sessions
            .filter { exercise.isCardio || !$0.sets.isEmpty }
            .sorted { $0.date > $1.date }
            .prefix(2))
    }

    private var advice: TrainingEngine.ProgressionAdvice? {
        TrainingEngine.progression(for: exercise)
    }

    var body: some View {
        if started {
            ExerciseLoggerView(exercise: exercise, defaultLocation: location, onFinished: onFinished)
        } else {
            previewContent
        }
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let advice {
                    coachCard(advice)
                }
                lastTimeCard
            }
            .padding(16)
            .padding(.bottom, 90)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { started = true }
            } label: {
                Label("Start Exercise", systemImage: "play.fill")
            }
            .buttonStyle(EmberButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(themeManager.background.opacity(0.94))
        }
    }

    private func coachCard(_ advice: TrainingEngine.ProgressionAdvice) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "Coach's Recommendation")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: coachIcon(advice.kind))
                    .font(.system(size: 22))
                    .foregroundColor(coachColor(advice.kind))
                Text("\(TrainingEngine.formatWeight(advice.weight)) lb")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.primaryText)
                Text(coachVerb(advice.kind))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(coachColor(advice.kind))
            }
            Text(advice.reason)
                .appBodyStyle()
                .foregroundColor(themeManager.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func coachIcon(_ kind: TrainingEngine.ProgressionKind) -> String {
        switch kind {
        case .increase: return "arrow.up.forward.circle.fill"
        case .decrease: return "arrow.down.forward.circle.fill"
        case .hold: return "equal.circle.fill"
        case .manual: return "pin.circle.fill"
        }
    }

    private func coachColor(_ kind: TrainingEngine.ProgressionKind) -> Color {
        switch kind {
        case .increase: return .appSuccess
        case .decrease: return .appWarning
        case .hold: return .appAccent
        case .manual: return .appCardio
        }
    }

    private func coachVerb(_ kind: TrainingEngine.ProgressionKind) -> String {
        switch kind {
        case .increase: return "GO UP"
        case .decrease: return "DELOAD"
        case .hold: return "HOLD"
        case .manual: return "YOUR TARGET"
        }
    }

    @ViewBuilder
    private var lastTimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: recentSessions.count > 1 ? "Last Two Sessions" : "Last Time")

            if recentSessions.isEmpty {
                Text("First time doing \(exercise.name) at \(location.rawValue.lowercased() == "home" ? "home" : location.rawValue) — log it and the coach takes over from here.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            } else {
                ForEach(Array(recentSessions.enumerated()), id: \.element.persistentModelID) { index, session in
                    if index > 0 { Divider() }
                    sessionBlock(session)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    @ViewBuilder
    private func sessionBlock(_ session: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .appCaptionStyle()
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.primaryText)
                Spacer()
                Text(session.date.formatted(.relative(presentation: .named)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
            }

            if exercise.isCardio {
                lastCardioRows(session)
            } else {
                ForEach(session.sets.sorted { $0.setNumber < $1.setNumber }, id: \.persistentModelID) { set in
                    SetRow(number: set.setNumber, reps: set.reps, weight: set.weight, difficulty: set.difficulty)
                }
            }
            if !session.machineSettings.isEmpty {
                Label(session.machineSettings, systemImage: "gearshape.fill")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            if !session.notes.isEmpty {
                Text("“\(session.notes)”")
                    .appCaptionStyle()
                    .italic()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func lastCardioRows(_ session: ExerciseSession) -> some View {
        HStack(spacing: 12) {
            if let run = session.runningTime, run > 0 {
                previewTile(value: "\(TrainingEngine.formatWeight(run))", label: "Run min")
            }
            if let speed = session.runningSpeed, speed > 0 {
                previewTile(value: "\(TrainingEngine.formatWeight(speed))", label: "mph")
            }
            if let intensity = session.intensityRating {
                previewTile(value: "\(intensity)/10", label: "Intensity")
            }
        }
    }

    private func previewTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(themeManager.primaryText)
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(themeManager.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - PR banner

private struct PRBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 18))
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(LinearGradient.ember)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Exercise logger

struct ExerciseLoggerView: View {
    let exercise: Exercise
    var defaultLocation: WorkoutLocation = .gym
    var onFinished: (ExerciseSession) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage("restTargetSeconds") private var restTarget: Int = 90

    // Strength state
    @State private var completedSets: [TempSet] = []
    @State private var reps = 8
    @State private var weight: Double?
    @State private var weightText = ""
    @State private var difficulty = 3
    @State private var setNotes = ""
    @State private var machineSettings = ""
    @State private var showingPlates = false

    // Cardio state
    @State private var warmUpTime = ""
    @State private var runningTime = ""
    @State private var coolDownTime = ""
    @State private var runningSpeed = ""
    @State private var intensity = 5.0

    // Shared state
    @State private var nextTargetText = ""
    @State private var sessionNotes = ""
    @State private var location: WorkoutLocation = .gym
    @State private var lastSetSavedAt: Date?
    // Wall-clock finish time for the rest timer, so it keeps counting while the
    // app is backgrounded instead of freezing a decrementing counter.
    @State private var restEndDate: Date?
    @State private var restNotifyTask: Task<Void, Never>?
    @State private var pendingConfirmAction: WeightConfirmAction?

    private enum WeightConfirmAction {
        case saveSet
        case finish
    }

    private var lastSession: ExerciseSession? {
        exercise.sessions.max(by: { $0.date < $1.date })
    }

    private var advice: TrainingEngine.ProgressionAdvice? {
        TrainingEngine.progression(for: exercise)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if restEndDate != nil {
                    restCountdownCard
                }

                if let advice, !exercise.isCardio {
                    coachHint(advice)
                }

                if exercise.isCardio {
                    cardioCard
                } else {
                    strengthCard
                    if !completedSets.isEmpty {
                        completedSetsCard
                    }
                }

                detailsCard

                Button(exercise.isCardio ? "Save Cardio" : "Finish Exercise") {
                    attemptFinish()
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(!canFinish)
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .dismissableKeyboard()
        .onAppear(perform: prefill)
        .onDisappear { restNotifyTask?.cancel() }
        .sheet(isPresented: $showingPlates) {
            plateSheet
        }
        .alert("Check that weight", isPresented: confirmBinding) {
            Button("Log Anyway") { confirmedAction() }
            Button("Cancel", role: .cancel) { pendingConfirmAction = nil }
        } message: {
            Text("\(weightText) lb is far beyond your history for \(exercise.name). Log it anyway?")
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: { pendingConfirmAction != nil },
            set: { if !$0 { pendingConfirmAction = nil } }
        )
    }

    private var canFinish: Bool {
        if exercise.isCardio {
            return Double(runningTime) != nil || Double(warmUpTime) != nil || Double(coolDownTime) != nil
        }
        return !completedSets.isEmpty || currentSetHasContent
    }

    private var currentSetHasContent: Bool {
        (Double(weightText) ?? 0) > 0 || reps != 8
    }

    // MARK: Rest countdown

    private var restCountdownCard: some View {
        // Drive the display off the wall clock so it stays accurate across
        // backgrounding — a paused decrementing counter used to freeze here.
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let remaining = restEndDate.map { max(0, Int($0.timeIntervalSince(context.date).rounded(.up))) } ?? 0
            let done = remaining <= 0

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.appAccentSoft, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: done ? 1 : CGFloat(remaining) / CGFloat(max(restTarget, 1)))
                        .stroke(done ? Color.appSuccess : Color.appAccent,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.appSuccess)
                    } else {
                        Text("\(remaining)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.appAccent)
                    }
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Rest complete" : "Resting")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.primaryText)
                    Text(done ? "You're recovered — start your next set" : "Next set when the ring closes")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }

                Spacer()

                Button(done ? "Done" : "Skip") {
                    restNotifyTask?.cancel()
                    restEndDate = nil
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(14)
            .appCard()
        }
    }

    private func startRestCountdown() {
        restNotifyTask?.cancel()
        restEndDate = Date().addingTimeInterval(TimeInterval(restTarget))
        // Best-effort haptic when the rest ends while the app is in the
        // foreground; the visual "Rest complete" state covers the rest.
        restNotifyTask = Task {
            try? await Task.sleep(for: .seconds(restTarget))
            if !Task.isCancelled {
                Haptics.shared.play(.restComplete)
            }
        }
    }

    // MARK: Coach hint

    private func coachHint(_ advice: TrainingEngine.ProgressionAdvice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: advice.kind == .increase
                  ? "arrow.up.forward.circle.fill"
                  : (advice.kind == .decrease ? "arrow.down.forward.circle.fill" : "lightbulb.fill"))
                .font(.system(size: 18))
                .foregroundColor(advice.kind == .increase ? .appSuccess : .appWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(advice.kind == .increase
                     ? "Coach says: go \(TrainingEngine.formatWeight(advice.weight)) lb"
                     : (advice.kind == .decrease
                        ? "Coach says: deload to \(TrainingEngine.formatWeight(advice.weight)) lb"
                        : "Coach says: \(TrainingEngine.formatWeight(advice.weight)) lb today"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.primaryText)
                Text(advice.reason)
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: Strength logging

    private var strengthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionKicker(text: "Set \(completedSets.count + 1)")
                Spacer()
                if let last = lastSession, let topWeight = last.sets.map(\.weight).max(), topWeight > 0 {
                    Text("Last time: \(TrainingEngine.formatWeight(topWeight)) lb")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
            }

            // Weight
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .appInputStyle()
                        .frame(maxWidth: .infinity)
                        .onChange(of: weightText) {
                            weight = Double(weightText)
                        }
                    Text("lb")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Button {
                        showingPlates = true
                    } label: {
                        Image(systemName: "circle.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.appAccent)
                            .padding(10)
                            .background(Color.appAccentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .hapticButton()
                    .accessibilityLabel("Plate calculator")
                }

                HStack(spacing: 8) {
                    ForEach([-5.0, -2.5, 2.5, 5.0], id: \.self) { delta in
                        Button {
                            bumpWeight(by: delta)
                        } label: {
                            Text(delta > 0 ? "+\(String(format: "%g", delta))" : String(format: "%g", delta))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(themeManager.inputBackground)
                                .foregroundColor(delta > 0 ? .appSuccess : .appDanger)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .hapticButton(.tap, pressScale: 0.94)
                    }
                }
            }

            // Reps
            HStack {
                Text("Reps")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        if reps > 1 { reps -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.appAccent)
                    }
                    .hapticButton(.tap, pressScale: 0.9)
                    Text("\(reps)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 48)
                        .foregroundColor(themeManager.primaryText)
                        .contentTransition(.numericText())
                    Button {
                        reps += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.appAccent)
                    }
                    .hapticButton(.tap, pressScale: 0.9)
                }
            }

            // Difficulty
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effort")
                        .appBodyStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Text(difficultyLabel(for: difficulty))
                        .appCaptionStyle()
                        .foregroundColor(themeManager.primaryText)
                }
                Spacer()
                DifficultyDots(rating: difficulty, size: 22, interactive: true) { tapped in
                    difficulty = tapped
                }
            }

            TextField("Set notes (optional)", text: $setNotes)
                .appInputStyle()

            Button {
                attemptSaveSet()
            } label: {
                Label("Log Set \(completedSets.count + 1)", systemImage: "checkmark")
            }
            .buttonStyle(EmberButtonStyle(compact: true))
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .appCard()
    }

    private var completedSetsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "Logged Sets")
            ForEach(completedSets) { set in
                SetRow(number: set.setNumber, reps: set.reps, weight: set.weight, difficulty: set.difficulty)
            }
        }
        .padding(16)
        .appCard()
    }

    // MARK: Cardio logging

    private var cardioCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Cardio")

            HStack(spacing: 10) {
                cardioField("Warm-up", text: $warmUpTime, unit: "min")
                cardioField("Run", text: $runningTime, unit: "min")
                cardioField("Cool-down", text: $coolDownTime, unit: "min")
            }
            cardioField("Speed", text: $runningSpeed, unit: "mph")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("How did it feel?")
                        .appBodyStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Spacer()
                    Text("\(Int(intensity))/10")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.appAccent)
                }
                Slider(value: $intensity, in: 1...10, step: 1)
                    .tint(.appAccent)
                    .onChange(of: intensity) { Haptics.shared.play(.detent) }
            }
        }
        .padding(16)
        .appCard()
    }

    private func cardioField(_ label: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
            HStack(spacing: 4) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .appInputStyle()
                Text(unit)
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
    }

    // MARK: Details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Details")

            Picker("Location", selection: $location) {
                ForEach(WorkoutLocation.allCases) { loc in
                    Text(loc.rawValue).tag(loc)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: location) { Haptics.shared.play(.selection) }

            if !exercise.isCardio {
                TextField("Machine settings (seat height, pin…)", text: $machineSettings)
                    .appInputStyle()

                HStack(spacing: 4) {
                    TextField("Weight next workout (optional)", text: $nextTargetText)
                        .keyboardType(.decimalPad)
                        .appInputStyle()
                    Text("lb")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
                Text("The coach will hold you to this next time instead of computing its own advice.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
            }

            TextField("Session notes (optional)", text: $sessionNotes, axis: .vertical)
                .lineLimit(2...4)
                .appInputStyle()
        }
        .padding(16)
        .appCard()
    }

    private var plateSheet: some View {
        NavigationStack {
            ScrollView {
                PlateCalculatorView(weight: $weight, exerciseName: exercise.name)
                    .padding(16)
                    .onChange(of: weight) {
                        if let weight {
                            weightText = TrainingEngine.formatWeight(weight)
                        }
                    }
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Plate Math")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { showingPlates = false }
                        .hapticButton(.tap, pressScale: 1)
                }
            }
        }
        .themedPresentation()
        .presentationDetents([.large])
    }

    // MARK: Actions

    private func prefill() {
        guard completedSets.isEmpty else { return }
        location = defaultLocation
        if let last = lastSession {
            machineSettings = last.machineSettings
        }
        if let advice, !exercise.isCardio {
            weight = advice.weight
            weightText = TrainingEngine.formatWeight(advice.weight)
        } else if let topWeight = lastSession?.sets.map(\.weight).max(), topWeight > 0 {
            weight = topWeight
            weightText = TrainingEngine.formatWeight(topWeight)
        }
    }

    private func bumpWeight(by delta: Double) {
        let current = Double(weightText) ?? 0
        let next = max(0, current + delta)
        weight = next
        weightText = TrainingEngine.formatWeight(next)
    }

    /// Compares against the exercise's historical max: obvious typos
    /// (695 instead of 95) get one confirmation step before saving.
    private func isWeightSuspicious(_ candidate: Double) -> Bool {
        let previousMax = exercise.sessions.flatMap(\.sets).map(\.weight).max() ?? 0
        if previousMax > 0 {
            return candidate >= max(previousMax * 1.5, previousMax + 100)
        }
        return candidate >= 500
    }

    private func attemptSaveSet() {
        let candidate = Double(weightText) ?? 0
        if candidate > 0 && isWeightSuspicious(candidate) {
            pendingConfirmAction = .saveSet
            return
        }
        saveSet()
    }

    private func saveSet() {
        let restSeconds: Int?
        if let lastSetSavedAt {
            restSeconds = Int(Date().timeIntervalSince(lastSetSavedAt))
        } else {
            restSeconds = nil
        }

        completedSets.append(TempSet(
            setNumber: completedSets.count + 1,
            reps: reps,
            weight: Double(weightText) ?? 0,
            notes: setNotes,
            difficulty: difficulty,
            restTimeSeconds: restSeconds
        ))
        setNotes = ""
        lastSetSavedAt = Date()
        startRestCountdown()
        Haptics.shared.play(.setLogged)
    }

    private func attemptFinish() {
        if !exercise.isCardio, currentSetHasContent, completedSets.isEmpty {
            // The user typed a first set but never tapped "Log Set" — capture it.
            let candidate = Double(weightText) ?? 0
            if candidate > 0 && isWeightSuspicious(candidate) {
                pendingConfirmAction = .finish
                return
            }
            saveSet()
        }
        finish()
    }

    private func confirmedAction() {
        switch pendingConfirmAction {
        case .saveSet:
            saveSet()
        case .finish:
            saveSet()
            finish()
        case nil:
            break
        }
        pendingConfirmAction = nil
    }

    private func finish() {
        restNotifyTask?.cancel()

        let session = ExerciseSession(
            date: Date(),
            machineSettings: machineSettings,
            totalSets: completedSets.count,
            notes: sessionNotes,
            location: location,
            warmUpTime: exercise.isCardio ? Double(warmUpTime) : nil,
            runningTime: exercise.isCardio ? Double(runningTime) : nil,
            coolDownTime: exercise.isCardio ? Double(coolDownTime) : nil,
            runningSpeed: exercise.isCardio ? Double(runningSpeed) : nil,
            intensityRating: exercise.isCardio ? Int(intensity) : nil
        )
        context.insert(session)
        session.exercise = exercise

        for temp in completedSets {
            let set = LoggedSet(
                setNumber: temp.setNumber,
                reps: temp.reps,
                weight: temp.weight,
                notes: temp.notes,
                difficulty: temp.difficulty,
                restTimeSeconds: temp.setNumber > 1 ? temp.restTimeSeconds : nil
            )
            context.insert(set)
            set.session = session
        }

        // The engine recomputes next time from this fresh session, so clear
        // any stale manual target — unless the user just pinned a new one.
        if let target = Double(nextTargetText), target > 0 {
            exercise.shouldIncreaseWeight = true
            exercise.suggestedNextWeight = target
        } else {
            exercise.shouldIncreaseWeight = false
            exercise.suggestedNextWeight = nil
        }

        try? context.save()
        // The celebration is played by the caller, which knows whether this
        // session was a PR and how big it was.
        onFinished(session)
        dismiss()
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

// MARK: - Exercise picker

struct ExercisePickerSheet: View {
    let focus: WorkoutType
    let location: WorkoutLocation
    var onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var searchText = ""
    @State private var showingCreate = false
    @State private var newName = ""
    @State private var newType: WorkoutType = .push

    private var filtered: [Exercise] {
        let atLocation = allExercises.filter { $0.location == location }
        guard !searchText.isEmpty else { return atLocation }
        return atLocation.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.persistentModelID) { exercise in
                    Button {
                        onPick(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: exercise.isCardio ? "figure.run" : "dumbbell.fill")
                                .foregroundColor(.appAccent)
                            Text(exercise.name)
                                .foregroundColor(themeManager.primaryText)
                            Spacer()
                            ChipLabel(text: exercise.type.rawValue)
                        }
                    }
                    .hapticButton(.tap, pressScale: 1)
                    .listRowBackground(themeManager.cardBackground)
                }

                Section {
                    Button {
                        newType = focus
                        showingCreate = true
                    } label: {
                        Label("Create New Exercise", systemImage: "plus")
                            .foregroundColor(.appAccent)
                    }
                    .hapticButton(.tap, pressScale: 1)
                    .listRowBackground(themeManager.cardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.background.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .hapticButton(.tap, pressScale: 1)
                }
            }
            .alert("New Exercise", isPresented: $showingCreate) {
                TextField("Name", text: $newName)
                Button("Add") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let exercise = Exercise(name: trimmed, type: newType, isCardio: false, location: location)
                    context.insert(exercise)
                    try? context.save()
                    onPick(exercise)
                    newName = ""
                    dismiss()
                }
                Button("Cancel", role: .cancel) { newName = "" }
            } message: {
                Text("It will be added to your \(focus.rawValue.lowercased()) day at \(location.rawValue.lowercased() == "home" ? "home" : location.rawValue).")
            }
        }
    }
}

// MARK: - Session summary

struct SessionSummaryView: View {
    let focus: WorkoutType
    let start: Date
    let sessions: [ExerciseSession]
    var onDone: () -> Void

    @EnvironmentObject var themeManager: ThemeManager

    private var totalSets: Int { sessions.reduce(0) { $0 + $1.sets.count } }
    private var volume: Double { TrainingEngine.totalVolume(sessions: sessions) }
    private var prs: [ExerciseSession] { sessions.filter(TrainingEngine.isPersonalRecord) }

    private var durationString: String {
        let minutes = max(1, Int(Date().timeIntervalSince(start)) / 60)
        return "\(minutes) min"
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient.ember)
                Text("\(focus.rawValue) Day Complete")
                    .appLargeTitleStyle()
                    .foregroundColor(themeManager.primaryText)
                Text(Date().formatted(date: .abbreviated, time: .shortened))
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            .padding(.top, 30)

            HStack(spacing: 12) {
                summaryTile(value: durationString, label: "Duration")
                summaryTile(value: "\(sessions.count)", label: "Exercises")
                summaryTile(value: "\(totalSets)", label: "Sets")
            }

            if volume > 0 {
                VStack(spacing: 4) {
                    Text("\(Int(volume).formatted()) lb")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.appAccent)
                    Text("Total weight moved")
                        .appCaptionStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .appCard()
            }

            if !prs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "PRs This Session 🏆")
                    ForEach(prs, id: \.persistentModelID) { session in
                        HStack {
                            Text(session.exercise?.name ?? "")
                                .appBodyStyle()
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryText)
                            Spacer()
                            Text("est. 1RM \(TrainingEngine.formatWeight(TrainingEngine.bestOneRepMax(in: session))) lb")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.appWarning)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
            }

            Spacer()

            Button("Done") { onDone() }
                .buttonStyle(EmberButtonStyle())
        }
        .padding(20)
        .background(themeManager.background.ignoresSafeArea())
        .onAppear {
            // The sheet's presentation animation is ~0.35s; starting the
            // fanfare a beat in lets the seal land with the first burst.
            Task {
                try? await Task.sleep(for: .milliseconds(280))
                Celebration.workout(
                    exercises: sessions.count,
                    sets: totalSets,
                    personalRecords: prs.count
                )
            }
        }
    }

    private func summaryTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(themeManager.primaryText)
            Text(label)
                .appCaptionStyle()
                .foregroundColor(themeManager.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .appCard()
    }
}
