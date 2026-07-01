import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct BodyWeightView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) var entries: [BodyWeightEntry]
    @Query var workoutDays: [WorkoutDay]
    @Query(sort: \ProgressPhoto.date, order: .reverse) var progressPhotos: [ProgressPhoto]
    
    @State private var showingAddEntry = false
    @State private var newWeight: Double? = nil
    @State private var newNotes: String = ""
    @State private var showingUnusualWeightAlert = false
    @State private var pendingWeightSave = false
    @State private var selectedProgressPhotoItem: PhotosPickerItem?
    @State private var progressPhotoNotes = ""
    
    // Creatine tracking for today
    @State private var tookCreatineToday = false
    @State private var creatineLogDate = Date()
    
    var sortedEntriesForChart: [BodyWeightEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    var creatineStreak: Int {
        calculateCreatineStreak()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Creatine Tracking Card
                        creatineCard

                        progressPhotosSection
                        
                        // Current Weight Card
                        if let latest = entries.first {
                            VStack(spacing: 10) {
                                Text("Current Weight")
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.secondaryText)
                                Text("\(latest.weight, specifier: "%.1f")")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(themeManager.primaryText)
                                Text("lbs")
                                    .font(.title3)
                                    .foregroundColor(themeManager.secondaryText)
                                
                                if entries.count > 1 {
                                    let diff = latest.weight - entries[1].weight
                                    HStack {
                                        Image(systemName: diff >= 0 ? "arrow.up" : "arrow.down")
                                        Text("\(abs(diff), specifier: "%.1f") lbs")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(diff >= 0 ? .red : .green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .background(themeManager.cardBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // Chart
                        if entries.count > 1 {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Weight Trend")
                                    .font(.headline)
                                    .foregroundColor(themeManager.primaryText)
                                
                                Chart {
                                    ForEach(sortedEntriesForChart) { entry in
                                        LineMark(
                                            x: .value("Date", entry.date),
                                            y: .value("Weight", entry.weight)
                                        )
                                        .foregroundStyle(Color.appAccent)
                                        
                                        AreaMark(
                                            x: .value("Date", entry.date),
                                            y: .value("Weight", entry.weight)
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.3), Color.clear],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .frame(height: 200)
                            }
                            .padding()
                            .background(themeManager.cardBackground)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // History
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Weight History")
                                .font(.headline)
                                .foregroundColor(themeManager.primaryText)
                            
                            if entries.isEmpty {
                                Text("No weight entries yet")
                                    .foregroundColor(themeManager.secondaryText)
                                    .padding()
                            } else {
                                Text("Swipe left to delete")
                                    .font(.caption)
                                    .foregroundColor(themeManager.secondaryText)
                                
                                List {
                                    ForEach(entries) { entry in
                                        WeightEntryRow(
                                            entry: entry,
                                            themeManager: themeManager
                                        )
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                    }
                                    .onDelete(perform: deleteEntries)
                                }
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(entries.count) * 80)
                            }
                        }
                        .padding()
                        .background(themeManager.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Weight & Creatine")
            .toolbarColorScheme(themeManager.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                addEntrySheet
            }
            .alert("Check weight", isPresented: $showingUnusualWeightAlert) {
                Button("Edit", role: .cancel) {
                    pendingWeightSave = false
                }
                Button("Save Anyway") {
                    pendingWeightSave = false
                    saveEntryConfirmed()
                }
            } message: {
                Text("This weight is much higher than your most recent entry. Is it correct?")
            }
            .onAppear(perform: loadCreatineStatus)
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    var creatineCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Creatine Tracking")
                        .font(.headline)
                        .foregroundColor(themeManager.primaryText)
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(creatineStreak) day streak")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    tookCreatineToday.toggle()
                    updateCreatineStatus(on: Date(), took: tookCreatineToday)
                    triggerHaptic()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tookCreatineToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 44))
                            .foregroundColor(tookCreatineToday ? .green : themeManager.secondaryText)
                        Text(tookCreatineToday ? "Done!" : "Take")
                            .font(.caption)
                            .foregroundColor(tookCreatineToday ? .green : themeManager.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
            
            // Weekly view
            HStack(spacing: 8) {
                ForEach(getLast7Days(), id: \.self) { date in
                    VStack(spacing: 4) {
                        Text(dayLetter(for: date))
                            .font(.caption2)
                            .foregroundColor(themeManager.secondaryText)
                        Circle()
                            .fill(hasCreatine(on: date) ? Color.green : themeManager.secondaryText.opacity(0.3))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Calendar.current.isDateInToday(date) ?
                                Circle().stroke(themeManager.primaryText, lineWidth: 2) : nil
                            )
                    }
                }
            }

            Divider()
                .background(themeManager.secondaryText.opacity(0.3))

            VStack(alignment: .leading, spacing: 10) {
                Text("Log Historical Creatine")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryText)

                DatePicker("Date", selection: $creatineLogDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.appAccent)

                Button(action: toggleHistoricalCreatine) {
                    Label(hasCreatine(on: creatineLogDate) ? "Mark as Not Taken" : "Mark as Taken", systemImage: hasCreatine(on: creatineLogDate) ? "xmark.circle" : "checkmark.circle.fill")
                        .foregroundColor(hasCreatine(on: creatineLogDate) ? .red : Color.appAccent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.secondaryBackground)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.top, 10)
    }

    var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Progress Photos")
                    .font(.headline)
                    .foregroundColor(themeManager.primaryText)

                Spacer()

                PhotosPicker(selection: $selectedProgressPhotoItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.appAccent)
                }
            }

            TextField("Photo notes (optional)", text: $progressPhotoNotes)
                .padding()
                .background(themeManager.secondaryBackground)
                .cornerRadius(10)
                .foregroundColor(themeManager.primaryText)

            if progressPhotos.isEmpty {
                Text("No progress photos yet")
                    .foregroundColor(themeManager.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(progressPhotos) { photo in
                            ProgressPhotoCard(photo: photo, themeManager: themeManager) {
                                deleteProgressPhoto(photo)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(16)
        .padding(.horizontal)
        .onChange(of: selectedProgressPhotoItem) {
            Task {
                await saveSelectedProgressPhoto()
            }
        }
    }
    
    var addEntrySheet: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (lbs)")
                            .font(.headline)
                            .foregroundColor(themeManager.secondaryText)
                        TextField("Enter weight", value: $newWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(themeManager.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(themeManager.primaryText)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.headline)
                            .foregroundColor(themeManager.secondaryText)
                        TextField("e.g. Morning weight", text: $newNotes)
                            .padding()
                            .background(themeManager.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(themeManager.primaryText)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingAddEntry = false }
                        .foregroundColor(themeManager.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(newWeight == nil)
                    .foregroundColor(newWeight == nil ? themeManager.secondaryText : Color.appAccent)
                }
            }
            .preferredColorScheme(themeManager.colorScheme)
        }
        .presentationDetents([.medium])
    }
    
    private func loadCreatineStatus() {
        let today = Calendar.current.startOfDay(for: Date())
        tookCreatineToday = workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: today) }?.tookCreatine ?? false
    }
    
    private func updateCreatineStatus(on date: Date, took: Bool) {
        let day = Calendar.current.startOfDay(for: date)
        
        if let existingDay = workoutDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            existingDay.tookCreatine = took
        } else {
            let newDay = WorkoutDay(date: day, type: .rest, tookCreatine: took)
            context.insert(newDay)
        }
        
        try? context.save()
    }

    private func toggleHistoricalCreatine() {
        let currentlyTaken = hasCreatine(on: creatineLogDate)
        updateCreatineStatus(on: creatineLogDate, took: !currentlyTaken)
        loadCreatineStatus()
        triggerHaptic()
    }
    
    private func hasCreatine(on date: Date) -> Bool {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.tookCreatine ?? false
    }
    
    private func getLast7Days() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: -6 + $0, to: today) }
    }
    
    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1))
    }
    
    private func calculateCreatineStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        if hasCreatine(on: currentDate) {
            streak = 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        } else {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        while hasCreatine(on: currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    private func triggerHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }

        try? context.save()
    }
    
    func saveEntry() {
        guard let weight = newWeight else { return }
        if shouldConfirmWeight(weight), !pendingWeightSave {
            pendingWeightSave = true
            showingUnusualWeightAlert = true
            return
        }

        saveEntryConfirmed()
    }

    func saveEntryConfirmed() {
        guard let weight = newWeight else { return }
        let entry = BodyWeightEntry(date: Date(), weight: weight, notes: newNotes)
        context.insert(entry)
        try? context.save()
        
        newWeight = nil
        newNotes = ""
        showingAddEntry = false
    }

    private func shouldConfirmWeight(_ weight: Double) -> Bool {
        guard let latestWeight = entries.first?.weight, latestWeight > 0 else {
            return weight >= 500
        }

        return weight >= max(latestWeight * 1.2, latestWeight + 25)
    }
    
    func deleteWeightEntry(_ entry: BodyWeightEntry) {
        context.delete(entry)
        try? context.save()
    }

    @MainActor
    private func saveSelectedProgressPhoto() async {
        guard let selectedProgressPhotoItem,
              let data = try? await selectedProgressPhotoItem.loadTransferable(type: Data.self) else {
            return
        }

        let photo = ProgressPhoto(date: Date(), imageData: data, notes: progressPhotoNotes)
        context.insert(photo)
        try? context.save()
        self.selectedProgressPhotoItem = nil
        progressPhotoNotes = ""
    }

    private func deleteProgressPhoto(_ photo: ProgressPhoto) {
        context.delete(photo)
        try? context.save()
    }
}

struct ProgressPhotoCard: View {
    let photo: ProgressPhoto
    let themeManager: ThemeManager
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 180)
                    .clipped()
                    .cornerRadius(10)
            }

            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)

            if !photo.notes.isEmpty {
                Text(photo.notes)
                    .font(.caption2)
                    .foregroundColor(themeManager.secondaryText)
                    .lineLimit(2)
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
                    .font(.caption)
            }
        }
        .frame(width: 140, alignment: .leading)
    }
}

struct WeightEntryRow: View {
    let entry: BodyWeightEntry
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryText)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            Spacer()
            Text("\(entry.weight, specifier: "%.1f") lbs")
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)
        }
        .padding()
        .background(themeManager.secondaryBackground)
        .cornerRadius(10)
    }
}
