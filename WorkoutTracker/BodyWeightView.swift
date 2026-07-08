import SwiftUI
import SwiftData
import Charts
import PhotosUI

/// Body tab: weight trend with weekly rate, creatine habit, progress photos.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]

    @State private var showingAddSheet = false
    @State private var entryToDelete: BodyWeightEntry?

    @AppStorage("progressPhotosEnabled") private var progressPhotosEnabled = true
    @AppStorage("progressPhotosLockEnabled") private var progressPhotosLockEnabled = false
    @AppStorage("progressPhotosPasswordHash") private var progressPhotosPasswordHash = ""
    @State private var photosUnlocked = false
    @State private var showingUnlockPrompt = false
    @State private var showingWrongPassword = false
    @State private var unlockEntry = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    weightHeroCard
                    creatineCard
                    if progressPhotosEnabled {
                        photosCard
                    }
                    historyCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Body")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                QuickWeightSheet()
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
                    Chart(recentEntries, id: \.persistentModelID) { entry in
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appCardio.opacity(0.3), Color.appCardio.opacity(0.02)],
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
                    }
                    .chartYScale(domain: weightDomain)
                    .chartXAxis(.hidden)
                    .frame(height: 110)
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

    private var weightDomain: ClosedRange<Double> {
        let values = recentEntries.map(\.weight)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.2, 2)
        return (minValue - padding)...(maxValue + padding)
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Last 14 days
            let calendar = Calendar.current
            HStack(spacing: 5) {
                ForEach(0..<14, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset - 13, to: calendar.startOfDay(for: Date()))!
                    VStack(spacing: 3) {
                        Circle()
                            .fill(tookCreatine(on: day) ? Color.appCreatine : themeManager.inputBackground)
                            .frame(height: 14)
                            .overlay(
                                Circle().stroke(offset == 13 ? Color.appAccent : .clear, lineWidth: 1.5)
                            )
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        updateCreatineStatus(on: day, took: !tookCreatine(on: day), context: context, days: workoutDays)
                    }
                }
            }
            Text("Tap any day to fix your history.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeManager.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: - Progress photos

    private var photosLocked: Bool {
        progressPhotosLockEnabled && !progressPhotosPasswordHash.isEmpty && !photosUnlocked
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Progress Photos")
                Spacer()
                if photosLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(themeManager.secondaryText)
                } else {
                    PhotoPickerButton()
                }
            }

            if photosLocked {
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            } else if photos.isEmpty {
                Text("Photos live only on this device. Add one to start your timeline.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(photos, id: \.persistentModelID) { photo in
                            ProgressPhotoCard(photo: photo)
                        }
                    }
                }
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
            Button("Cancel", role: .cancel) { unlockEntry = "" }
        }
        .alert("Wrong Password", isPresented: $showingWrongPassword) {
            Button("OK") {}
        } message: {
            Text("Try again to see your photos.")
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

// MARK: - Photo picker button

private struct PhotoPickerButton: View {
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
                    context.insert(ProgressPhoto(date: Date(), imageData: data))
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
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
