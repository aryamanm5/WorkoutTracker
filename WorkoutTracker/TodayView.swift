import SwiftUI
import SwiftData

/// Home dashboard: adaptive focus recommendation, recovery snapshot,
/// weekly stats, quick logging, and the door into a live training session.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weightEntries: [BodyWeightEntry]

    @State private var focusOverride: WorkoutType?
    @State private var showingSession = false
    @State private var showingWeightSheet = false
    @AppStorage("preferredLocation") private var preferredLocationRaw = WorkoutLocation.gym.rawValue

    private var trainingLocation: WorkoutLocation {
        WorkoutLocation.from(stored: preferredLocationRaw)
    }

    private var recommendation: TrainingEngine.SplitRecommendation {
        TrainingEngine.recommendation(sessions: sessions)
    }

    private var activeFocus: WorkoutType {
        focusOverride ?? recommendation.type
    }

    private var todaysSessions: [ExerciseSession] {
        sessions.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var thisWeeksSessions: [ExerciseSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessions.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    focusCard
                    statsRow
                    recoveryCard
                    if !recentPRs.isEmpty {
                        prCard
                    }
                    quickActionsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(themeManager.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showingSession) {
            ActiveSessionView(focus: activeFocus, location: trainingLocation)
                .themedPresentation()
        }
        .sheet(isPresented: $showingWeightSheet) {
            QuickWeightSheet()
                .themedPresentation()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .appKickerStyle()
                .kerning(1.4)
                .foregroundColor(.appAccent)
                .textCase(.uppercase)
            Text(greeting)
                .appLargeTitleStyle()
                .foregroundColor(themeManager.primaryText)
        }
        .padding(.top, 12)
    }

    // MARK: - Focus card

    private var trainedToday: Bool { !todaysSessions.isEmpty }

    @ViewBuilder
    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionKicker(text: trainedToday ? "Today's Training" : "Coach's Pick")
                Spacer()
                focusSwitcher
            }

            if trainedToday {
                trainedSummary
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activeFocus == .rest ? "Rest & Recover" : "\(activeFocus.rawValue) Day")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.appAccent)
                    Text(focusOverride == nil
                         ? recommendation.reason
                         : "Your call — coach suggested \(recommendation.type.rawValue.lowercased()), but you know your body best.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if activeFocus != .rest {
                locationToggle

                Button {
                    showingSession = true
                } label: {
                    Label(trainedToday ? "Train More" : "Start Training",
                          systemImage: "play.fill")
                }
                .buttonStyle(EmberButtonStyle())
                .accessibilityIdentifier("startTraining")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var trainedSummary: some View {
        let volume = TrainingEngine.totalVolume(sessions: todaysSessions)
        let names = Set(todaysSessions.compactMap { $0.exercise?.name })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.appSuccess)
                Text("Trained Today")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(themeManager.primaryText)
            }
            Text("\(names.count) exercise\(names.count == 1 ? "" : "s")\(volume > 0 ? " · \(Int(volume).formatted()) lb moved" : "")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.secondaryText)
        }
    }

    /// Where you're training decides which exercise library, coach history,
    /// and charts the session uses — pick it before starting.
    private var locationToggle: some View {
        HStack(spacing: 8) {
            ForEach(WorkoutLocation.allCases) { loc in
                let isSelected = trainingLocation == loc
                Button {
                    preferredLocationRaw = loc.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: loc.icon)
                            .font(.system(size: 12, weight: .bold))
                        Text(loc.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isSelected ? .white : themeManager.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isSelected ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(themeManager.inputBackground))
                    .clipShape(Capsule())
                }
                .hapticButton(.selection)
                .accessibilityIdentifier("location_\(loc == .home ? "home" : "gym")")
            }
        }
    }

    private var focusSwitcher: some View {
        Menu {
            ForEach(WorkoutType.allCases.filter { $0 != .rest }, id: \.self) { type in
                Button {
                    focusOverride = type
                } label: {
                    if type == activeFocus {
                        Label("\(type.rawValue) Day", systemImage: "checkmark")
                    } else {
                        Text("\(type.rawValue) Day")
                    }
                }
            }
            Button {
                focusOverride = .rest
            } label: {
                if activeFocus == .rest {
                    Label("Rest Day", systemImage: "checkmark")
                } else {
                    Text("Rest Day")
                }
            }
            if focusOverride != nil {
                Divider()
                Button("Back to Coach's Pick") { focusOverride = nil }
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.appAccent)
                .padding(8)
                .background(Color.appAccentSoft)
                .clipShape(Circle())
        }
        // Menu items are system-rendered, so a ButtonStyle can't reach them:
        // tap the label, then confirm the pick when the selection lands.
        .simultaneousGesture(TapGesture().onEnded { Haptics.shared.play(.tap) })
        .onChange(of: focusOverride) { Haptics.shared.play(.selection) }
        .accessibilityLabel("Change focus")
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(
                icon: "flame.fill",
                iconColor: .appAccent,
                value: "\(TrainingEngine.currentStreak(sessions: sessions))",
                label: "Day Streak"
            )
            StatTile(
                icon: "calendar",
                iconColor: .appCardio,
                value: "\(Set(thisWeeksSessions.map { Calendar.current.startOfDay(for: $0.date) }).count)",
                label: "Days This Week"
            )
            StatTile(
                icon: "scalemass.fill",
                iconColor: .appSuccess,
                value: weightEntries.first.map { TrainingEngine.formatWeight($0.weight) } ?? "—",
                label: "Body Weight"
            )
        }
    }

    // MARK: - Recovery

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Muscle Recovery")
                Spacer()
                Text("Last 72h")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
            }
            MuscleDiagramView(intensities: TrainingEngine.muscleFatigue(sessions: sessions))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .appCard()
    }

    // MARK: - PRs

    private var recentPRs: [TrainingEngine.PersonalRecord] {
        Array(TrainingEngine.recentPRs(sessions: sessions, within: 14).prefix(3))
    }

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Recent PRs")
            ForEach(recentPRs) { pr in
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.appWarning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pr.exerciseName)
                            .appBodyStyle()
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryText)
                        Text(pr.date.formatted(.dateTime.month(.abbreviated).day()))
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(TrainingEngine.formatWeight(pr.oneRepMax)) lb")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.appAccent)
                        Text("est. 1RM")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.secondaryText)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Quick actions

    private var todayDay: WorkoutDay? {
        workoutDays.first { Calendar.current.isDateInToday($0.date) }
    }

    private var quickActionsCard: some View {
        HStack(spacing: 12) {
            Button {
                toggleCreatine()
            } label: {
                let taken = todayDay?.tookCreatine ?? false
                HStack(spacing: 8) {
                    Image(systemName: taken ? "checkmark.circle.fill" : "pills.fill")
                    Text(taken ? "Creatine ✓" : "Log Creatine")
                        .lineLimit(1)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(taken ? .white : .appCreatine)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(taken ? AnyShapeStyle(Color.appCreatine) : AnyShapeStyle(Color.appCreatine.opacity(0.14)))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            // Follows the state rather than the tap: taking creatine rises,
            // undoing it falls.
            .hapticButton((todayDay?.tookCreatine ?? false) ? .toggleOff : .toggleOn, pressScale: 0.97)

            Button {
                showingWeightSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scalemass.fill")
                    Text("Log Weight")
                        .lineLimit(1)
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.appCardio)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appCardio.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .hapticButton(.soft, pressScale: 0.97)
        }
    }

    private func toggleCreatine() {
        let taken = todayDay?.tookCreatine ?? false
        updateCreatineStatus(on: Date(), took: !taken, context: context, days: workoutDays)
    }
}

// MARK: - Shared helpers

/// Sets creatine status for a calendar day, creating its WorkoutDay if needed.
/// Shared by the Today dashboard and the Body tab.
func updateCreatineStatus(on date: Date, took: Bool, context: ModelContext, days: [WorkoutDay]) {
    let calendar = Calendar.current
    if let existing = days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
        existing.tookCreatine = took
    } else {
        let day = WorkoutDay(date: date, type: .rest, tookCreatine: took)
        context.insert(day)
    }
    try? context.save()
}

struct StatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(themeManager.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeManager.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .appCard()
    }
}

// MARK: - Quick weight sheet

struct QuickWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]

    @State private var weightText = ""
    @State private var notes = ""
    @State private var showingConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    TextField("Weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .appInputStyle()
                    Text("lb")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.secondaryText)
                }

                TextField("Notes (optional)", text: $notes)
                    .appInputStyle()

                Button("Save") { attemptSave() }
                    .buttonStyle(EmberButtonStyle())
                    .disabled(Double(weightText) == nil)

                Spacer()
            }
            .padding(20)
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Check that weight", isPresented: $showingConfirm) {
                Button("Save Anyway") { save() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(weightText) lb is a big jump from your last entry. Save it anyway?")
            }
        }
    }

    private func attemptSave() {
        guard let weight = Double(weightText) else { return }
        if let latest = entries.first?.weight {
            if weight >= max(latest * 1.2, latest + 25) || weight <= min(latest * 0.8, latest - 25) {
                showingConfirm = true
                return
            }
        } else if weight >= 500 {
            showingConfirm = true
            return
        }
        save()
    }

    private func save() {
        guard let weight = Double(weightText) else { return }
        context.insert(BodyWeightEntry(date: Date(), weight: weight, notes: notes))
        try? context.save()
        dismiss()
    }
}
