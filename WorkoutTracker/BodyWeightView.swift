import SwiftUI
import SwiftData
import Charts

struct BodyWeightView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) var entries: [BodyWeightEntry]
    @Query var workoutDays: [WorkoutDay]
    
    @State private var showingAddEntry = false
    @State private var newWeight: Double? = nil
    @State private var newNotes: String = ""
    
    // Creatine tracking for today
    @State private var tookCreatineToday = false
    
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
                        
                        // Current Weight Card
                        if let latest = entries.first {
                            VStack(spacing: 10) {
                                Text("Current Weight")
                                    .appBodyStyle()
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
                                    .appBodyStyle()
                                    .foregroundColor(diff >= 0 ? .red : .green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .appCard()
                            .padding(.horizontal)
                        }
                        
                        // Chart
                        if entries.count > 1 {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Weight Trend")
                                    .appHeadingStyle()
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
                            .appCard()
                            .padding(.horizontal)
                        }
                        
                        // History
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Weight History")
                                .appHeadingStyle()
                                .foregroundColor(themeManager.primaryText)
                            
                            if entries.isEmpty {
                                Text("No weight entries yet")
                                    .foregroundColor(themeManager.secondaryText)
                                    .padding()
                            } else {
                                Text("Swipe left to delete")
                                    .appCaptionStyle()
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
                        .appCard()
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
            .onAppear(perform: loadCreatineStatus)
            .preferredColorScheme(themeManager.colorScheme)
        }
    }
    
    var creatineCard: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Creatine Tracking")
                        .appHeadingStyle()
                        .foregroundColor(themeManager.primaryText)
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(creatineStreak) day streak")
                            .appBodyStyle()
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    tookCreatineToday.toggle()
                    updateCreatineStatus(took: tookCreatineToday)
                    triggerHaptic()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tookCreatineToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 44))
                            .foregroundColor(tookCreatineToday ? .green : themeManager.secondaryText)
                        Text(tookCreatineToday ? "Done!" : "Take")
                            .appCaptionStyle()
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
        }
        .padding()
        .appCard()
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    var addEntrySheet: some View {
        NavigationStack {
            ZStack {
                themeManager.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (lbs)")
                            .appHeadingStyle()
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
                            .appHeadingStyle()
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
    
    private func updateCreatineStatus(took: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let existingDay = workoutDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            existingDay.tookCreatine = took
        } else {
            let newDay = WorkoutDay(date: today, type: .rest, tookCreatine: took)
            context.insert(newDay)
        }
        
        try? context.save()
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
        let entry = BodyWeightEntry(date: Date(), weight: weight, notes: newNotes)
        context.insert(entry)
        try? context.save()
        
        newWeight = nil
        newNotes = ""
        showingAddEntry = false
    }
    
    func deleteWeightEntry(_ entry: BodyWeightEntry) {
        context.delete(entry)
        try? context.save()
    }
}

struct WeightEntryRow: View {
    let entry: BodyWeightEntry
    let themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .appCaptionStyle()
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
