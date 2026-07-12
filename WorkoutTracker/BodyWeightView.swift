import SwiftUI
import SwiftData
import Charts
import PhotosUI

private enum BodySection: String, CaseIterable, Identifiable {
    case weight = "Weight"
    case creatine = "Creatine"
    case photos = "Photos"
    var id: String { rawValue }
}

/// Body tab: split into Weight, Creatine, and Progress Photos pages, toggled
/// with a segmented bar at the top.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var section: BodySection = .weight
    @State private var showingAddSheet = false
    @State private var entryToDelete: BodyWeightEntry?

    // Weight goal
    @AppStorage("weightGoal") private var weightGoal: Double = 0
    @AppStorage("weightGoalDate") private var weightGoalDateStamp: Double = 0
    @State private var showingGoalSheet = false

    // Creatine historical logging
    @State private var showingCreatineCalendar = false
    @State private var historicalDate = Date()

    @AppStorage("progressPhotosEnabled") private var progressPhotosEnabled = true
    @AppStorage("progressPhotosLockEnabled") private var progressPhotosLockEnabled = false
    @AppStorage("progressPhotosPasswordHash") private var progressPhotosPasswordHash = ""
    @State private var photosUnlocked = false
    @State private var showingUnlockPrompt = false
    @State private var showingWrongPassword = false
    @State private var unlockEntry = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(BodySection.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch section {
                        case .weight:
                            weightHeroCard
                            goalCard
                            historyCard
                        case .creatine:
                            creatineCard
                        case .photos:
                            if progressPhotosEnabled {
                                photosCard
                            } else {
                                photosDisabledCard
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Body")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if section == .weight {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.appAccent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                QuickWeightSheet()
                    .themedPresentation()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingGoalSheet) {
                WeightGoalSheet(goal: $weightGoal, dateStamp: $weightGoalDateStamp)
                    .themedPresentation()
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: Binding(
                    get: { entryToDelete != nil },
                    set: { if !$0 { entryToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = entryToDelete {
                        context.delete(entry)
                        try? context.save()
                    }
                    entryToDelete = nil
                }
                Button("Cancel", role: .cancel) { entryToDelete = nil }
            }
        }
    }

    // MARK: - Weight hero

    private var recentEntries: [BodyWeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return entries.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    /// lb per week over the last 30 days of entries.
    private var weeklyRate: Double? {
        let recent = recentEntries
        guard let first = recent.first, let last = recent.last, recent.count >= 2 else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86400
        guard days >= 3 else { return nil }
        return (last.weight - first.weight) / days * 7
    }

    private var goalDate: Date? {
        weightGoalDateStamp > 0 ? Date(timeIntervalSince1970: weightGoalDateStamp) : nil
    }

    private var hasGoal: Bool { weightGoal > 0 }

    private var weightHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Body Weight")

            if let latest = entries.first {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TrainingEngine.formatWeight(latest.weight))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(themeManager.primaryText)
                    Text("lb")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Spacer()
                    if let rate = weeklyRate {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: rate > 0.05 ? "arrow.up.right" : (rate < -0.05 ? "arrow.down.right" : "arrow.right"))
                                Text("\(String(format: "%+.1f", rate)) lb")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(rate > 0.05 ? .appDanger : (rate < -0.05 ? .appSuccess : themeManager.secondaryText))
                            Text("per week")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(themeManager.secondaryText)
                        }
                    }
                }

                if recentEntries.count >= 2 {
                    weightChart
                }

                Text("Logged \(latest.date.formatted(.relative(presentation: .named)))")
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
            } else {
                Text("No entries yet — tap + to log your first weigh-in.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var weightChart: some View {
        Chart {
            ForEach(recentEntries, id: \.persistentModelID) { entry in
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appCardio.opacity(0.28), Color.appCardio.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color.appCardio)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color.appCardio)
                .symbolSize(18)
            }

            // Goal line in context of the trend.
            if hasGoal {
                RuleMark(y: .value("Goal", weightGoal))
                    .foregroundStyle(Color.appAccent.opacity(0.9))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(TrainingEngine.formatWeight(weightGoal))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.appAccent)
                    }
            }
        }
        .chartYScale(domain: weightDomain)
        // Clip the plot so the area gradient can't bleed past the frame.
        .chartPlotStyle { plot in
            plot.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(themeManager.cardBorder.opacity(0.4))
                AxisValueLabel {
                    if let w = value.as(Double.self) {
                        Text("\(Int(w))")
                            .font(.system(size: 10))
                            .foregroundColor(themeManager.secondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 140)
    }

    private var weightDomain: ClosedRange<Double> {
        var values = recentEntries.map(\.weight)
        if hasGoal { values.append(weightGoal) }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.15, 2)
        return (minValue - padding)...(maxValue + padding)
    }

    // MARK: - Weight goal

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Goal")
                Spacer()
                Button(hasGoal ? "Edit" : "Set Goal") { showingGoalSheet = true }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appAccent)
            }

            if hasGoal, let latest = entries.first {
                let remaining = latest.weight - weightGoal
                let losing = remaining > 0
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TrainingEngine.formatWeight(weightGoal))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.appAccent)
                    Text("lb")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.secondaryText)
                    Spacer()
                    if let date = goalDate {
                        Text("by \(date.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.secondaryText)
                    }
                }

                GoalProgressBar(start: goalStartWeight, current: latest.weight, goal: weightGoal)

                Text(goalStatusText(remaining: remaining, losing: losing))
                    .appCaptionStyle()
                    .foregroundColor(themeManager.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Set a target weight and date to track progress against it.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    /// Anchor the progress bar to the earliest recent entry (or current if none).
    private var goalStartWeight: Double {
        recentEntries.first?.weight ?? entries.first?.weight ?? weightGoal
    }

    private func goalStatusText(remaining: Double, losing: Bool) -> String {
        let absRemaining = abs(remaining)
        if absRemaining < 0.1 {
            return "🎉 You've hit your goal weight!"
        }
        var text = "\(TrainingEngine.formatWeight(absRemaining)) lb to \(losing ? "lose" : "gain")."
        if let date = goalDate {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
            if days > 0 {
                let perWeek = absRemaining / Double(days) * 7
                text += " \(days) day\(days == 1 ? "" : "s") left — about \(String(format: "%.1f", perWeek)) lb/week needed."
            } else {
                text += " Target date has passed."
            }
        }
        return text
    }

    // MARK: - Creatine

    private var creatineStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if !tookCreatine(on: cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        while tookCreatine(on: cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return streak
    }

    private func tookCreatine(on date: Date) -> Bool {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.tookCreatine ?? false
    }

    private var creatineCard: some View {
        let takenToday = tookCreatine(on: Date())
        let calendar = Calendar.current

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionKicker(text: "Creatine")
                Spacer()
                if creatineStreak > 0 {
                    ChipLabel(text: "🔥 \(creatineStreak) day\(creatineStreak == 1 ? "" : "s")", color: .appCreatine)
                }
            }

            Button {
                updateCreatineStatus(on: Date(), took: !takenToday, context: context, days: workoutDays)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack {
                    Image(systemName: takenToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                    Text(takenToday ? "Taken today" : "Mark taken today")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(takenToday ? .white : .appCreatine)
                .padding(14)
                .background(takenToday ? AnyShapeStyle(Color.appCreatine) : AnyShapeStyle(Color.appCreatine.opacity(0.12)))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Past 7 days — tap any dot to toggle.
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset - 6, to: calendar.startOfDay(for: Date()))!
                    let isToday = offset == 6
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(themeManager.secondaryText)
                        Circle()
                            .fill(tookCreatine(on: day) ? Color.appCreatine : themeManager.inputBackground)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(isToday ? Color.appAccent : .clear, lineWidth: 2)
                            )
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        updateCreatineStatus(on: day, took: !tookCreatine(on: day), context: context, days: workoutDays)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }

            // Back-dating lives behind a button so it stays out of the way.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showingCreatineCalendar.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(showingCreatineCalendar ? "Hide calendar" : "Log an earlier day")
                    Spacer()
                    Image(systemName: showingCreatineCalendar ? "chevron.up" : "chevron.down")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appAccent)
            }

            if showingCreatineCalendar {
                VStack(spacing: 10) {
                    DatePicker("Day", selection: $historicalDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.appCreatine)

                    let took = tookCreatine(on: historicalDate)
                    Button {
                        updateCreatineStatus(on: historicalDate, took: !took, context: context, days: workoutDays)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: took ? "checkmark.circle.fill" : "circle")
                            Text(took ? "Taken on \(historicalDate.formatted(.dateTime.month(.abbreviated).day())) — tap to clear"
                                      : "Mark \(historicalDate.formatted(.dateTime.month(.abbreviated).day())) taken")
                            Spacer()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(took ? .white : .appCreatine)
                        .padding(12)
                        .background(took ? AnyShapeStyle(Color.appCreatine) : AnyShapeStyle(Color.appCreatine.opacity(0.12)))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(12)
                .background(themeManager.inputBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Progress photos

    private var photosLocked: Bool {
        progressPhotosLockEnabled && !progressPhotosPasswordHash.isEmpty && !photosUnlocked
    }

    private var photosDisabledCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionKicker(text: "Progress Photos")
            Text("Progress photos are turned off. Enable them in Settings to start a timeline.")
                .appBodyStyle()
                .foregroundColor(themeManager.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    @ViewBuilder
    private var photosCard: some View {
        if photosLocked {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionKicker(text: "Progress Photos")
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.secondaryText)
                }
                Button {
                    showingUnlockPrompt = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                        Text("Photos are locked — tap to unlock")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Spacer()
                    }
                    .foregroundColor(.appAccent)
                    .padding(14)
                    .background(Color.appAccentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
            .alert("Unlock Progress Photos", isPresented: $showingUnlockPrompt) {
                SecureField("Password", text: $unlockEntry)
                Button("Unlock") {
                    if PasscodeHasher.hash(unlockEntry.trimmingCharacters(in: .whitespaces)) == progressPhotosPasswordHash {
                        photosUnlocked = true
                    } else {
                        showingWrongPassword = true
                    }
                    unlockEntry = ""
                }
                Button("Forgot Password?") {
                    unlockEntry = ""
                    // Device auth clears the forgotten password entirely so a
                    // fresh one can be set from Settings.
                    PasscodeHasher.recoverWithDeviceAuth {
                        progressPhotosLockEnabled = false
                        progressPhotosPasswordHash = ""
                        photosUnlocked = true
                    }
                }
                Button("Cancel", role: .cancel) { unlockEntry = "" }
            }
            .alert("Wrong Password", isPresented: $showingWrongPassword) {
                Button("OK") {}
            } message: {
                Text("Try again to see your photos.")
            }
        } else {
            // One section per pose so you scroll a single pose across time.
            ForEach(ProgressPose.allCases) { pose in
                PoseTimelineCard(pose: pose, photos: photos.filter { $0.pose == pose })
            }
        }
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionKicker(text: "History")
                .padding(.bottom, 8)
            if entries.isEmpty {
                Text("Weigh-ins will appear here.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
            ForEach(Array(entries.prefix(30)), id: \.persistentModelID) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(TrainingEngine.formatWeight(entry.weight)) lb")
                            .appBodyStyle()
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryText)
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                    Spacer()
                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .appCaptionStyle()
                            .foregroundColor(themeManager.secondaryText)
                            .lineLimit(1)
                    }
                    Button {
                        entryToDelete = entry
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.appDanger.opacity(0.7))
                    }
                }
                .padding(.vertical, 8)
                if entry.persistentModelID != entries.prefix(30).last?.persistentModelID {
                    Divider()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

// MARK: - Goal progress bar

private struct GoalProgressBar: View {
    let start: Double
    let current: Double
    let goal: Double

    @EnvironmentObject var themeManager: ThemeManager

    /// 0...1 fraction of the start→goal distance covered so far.
    private var fraction: Double {
        let total = abs(goal - start)
        guard total > 0.01 else { return 1 }
        let done = abs(current - start)
        return min(max(done / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(themeManager.inputBackground)
                Capsule()
                    .fill(LinearGradient.ember)
                    .frame(width: max(8, geo.size.width * fraction))
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Weight goal sheet

private struct WeightGoalSheet: View {
    @Binding var goal: Double
    @Binding var dateStamp: Double

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var goalText = ""
    @State private var targetDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target weight")
                        .appBodyStyle()
                        .foregroundColor(themeManager.primaryText)
                    HStack {
                        TextField("Weight", text: $goalText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .appInputStyle()
                        Text("lb")
                            .appHeadingStyle()
                            .foregroundColor(themeManager.secondaryText)
                    }
                }

                DatePicker("Target date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                    .tint(.appAccent)
                    .foregroundColor(themeManager.primaryText)

                Button("Save Goal") {
                    if let value = Double(goalText), value > 0 {
                        goal = value
                        dateStamp = targetDate.timeIntervalSince1970
                    }
                    dismiss()
                }
                .buttonStyle(EmberButtonStyle())
                .disabled(Double(goalText) == nil)

                if goal > 0 {
                    Button("Clear Goal", role: .destructive) {
                        goal = 0
                        dateStamp = 0
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                }

                Spacer()
            }
            .padding(20)
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if goal > 0 { goalText = TrainingEngine.formatWeight(goal) }
                if dateStamp > 0 { targetDate = Date(timeIntervalSince1970: dateStamp) }
            }
        }
    }
}

// MARK: - Pose timeline

private struct PoseTimelineCard: View {
    let pose: ProgressPose
    let photos: [ProgressPhoto]

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: pose.rawValue)
                if !photos.isEmpty {
                    Text("\(photos.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(themeManager.secondaryText)
                }
                Spacer()
                PhotoPickerButton(pose: pose)
            }

            if photos.isEmpty {
                Text("No \(pose.rawValue.lowercased()) shots yet — add one to start comparing.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            } else {
                // Oldest → newest so scrolling right walks forward in time.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos.sorted { $0.date < $1.date }, id: \.persistentModelID) { photo in
                            ProgressPhotoCard(photo: photo)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

// MARK: - Photo picker button

private struct PhotoPickerButton: View {
    let pose: ProgressPose

    @Environment(\.modelContext) private var context
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Label("Add", systemImage: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appAccent)
        }
        .onChange(of: selectedItem) {
            guard let item = selectedItem else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self) {
                    context.insert(ProgressPhoto(date: Date(), imageData: data, pose: pose))
                    try? context.save()
                }
                selectedItem = nil
            }
        }
    }
}

// MARK: - Photo card

private struct ProgressPhotoCard: View {
    let photo: ProgressPhoto

    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            HStack {
                Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(themeManager.secondaryText)
                Spacer()
                Button {
                    confirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.appDanger.opacity(0.7))
                }
            }
            .frame(width: 130)
        }
        .confirmationDialog("Delete this photo?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(photo)
                try? context.save()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
