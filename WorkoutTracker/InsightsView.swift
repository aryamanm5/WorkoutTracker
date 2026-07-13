import SwiftUI
import SwiftData
import Charts

/// Analytics home: training-heat calendar, weekly muscle volume,
/// strength trends (est. 1RM), and per-exercise drill-downs.
struct InsightsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @Query private var workoutDays: [WorkoutDay]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var chartExerciseName: String?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            statsRow
                            calendarCard
                            volumeCard
                            trendCard
                            exerciseListCard
                        }
                        .padding(16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(themeManager.background.ignoresSafeArea())
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundColor(.appAccent)
            Text("No training yet")
                .appHeadingStyle()
                .foregroundColor(themeManager.primaryText)
            Text("Finish your first session and your trends, calendar and recovery will light up here.")
                .appBodyStyle()
                .foregroundColor(themeManager.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Stats

    private var trailing7: [ExerciseSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessions.filter { $0.date >= cutoff }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(
                icon: "flame.fill",
                iconColor: .appAccent,
                value: "\(TrainingEngine.currentStreak(sessions: sessions))",
                label: "Day Streak"
            )
            StatTile(
                icon: "checkmark.circle.fill",
                iconColor: .appSuccess,
                value: "\(Set(sessions.map { Calendar.current.startOfDay(for: $0.date) }).count)",
                label: "Total Days"
            )
            StatTile(
                icon: "scalemass",
                iconColor: .appCardio,
                value: shortVolume(TrainingEngine.totalVolume(sessions: trailing7)),
                label: "7-Day Volume"
            )
        }
    }

    private func shortVolume(_ volume: Double) -> String {
        if volume >= 10_000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }

    // MARK: - Heat calendar

    private var calendar: Calendar { Calendar.current }

    /// Training load per day this month: hard sets + a cardio bonus.
    private var dayScores: [Date: Int] {
        var scores: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            let score = session.exercise?.isCardio == true ? 3 : session.sets.count
            scores[day, default: 0] += score
        }
        return scores
    }

    private var calendarCard: some View {
        let scores = dayScores
        let maxScore = max(scores.values.max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionKicker(text: "Training Heat")
                Spacer()
                Button {
                    withAnimation { displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth)! }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appAccent)
                        .frame(width: 30, height: 30)
                }
                .hapticButton(.tap, pressScale: 0.9)
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.primaryText)
                    .frame(minWidth: 120)
                Button {
                    withAnimation { displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth)! }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appAccent)
                        .frame(width: 30, height: 30)
                }
                .hapticButton(.tap, pressScale: 0.9)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(themeManager.secondaryText)
                }
                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, day in
                    if let day {
                        NavigationLink {
                            DayDetailView(date: day)
                        } label: {
                            HeatDayCell(
                                date: day,
                                intensity: scores[day].map { Double($0) / Double(maxScore) } ?? 0,
                                trained: scores[day] != nil,
                                tookCreatine: workoutDays.first {
                                    calendar.isDate($0.date, inSameDayAs: day)
                                }?.tookCreatine ?? false
                            )
                        }
                        .hapticButton(.tap, pressScale: 0.92)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            HStack(spacing: 6) {
                Text("Light")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
                ForEach([0.2, 0.45, 0.7, 1.0], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.heat(value))
                        .frame(width: 14, height: 10)
                }
                Text("Heavy")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
                Spacer()
                Circle().fill(Color.appCreatine).frame(width: 6, height: 6)
                Text("Creatine")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .appCard()
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func daysInMonth() -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = interval.start
        let weekdayOfFirst = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 0

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            days.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return days
    }

    // MARK: - Weekly volume by muscle

    private var volumeCard: some View {
        let volume = TrainingEngine.setVolume(sessions: sessions, days: 7)
        let top = volume.sorted { $0.value > $1.value }.prefix(8)
        let maxSets = max(top.first?.value ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Weekly Sets by Muscle")
                Spacer()
                Text("Last 7 days")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
            }

            if top.isEmpty {
                Text("No strength sets logged this week yet.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            } else {
                ForEach(Array(top), id: \.key) { muscle, sets in
                    HStack(spacing: 10) {
                        Text(muscle.displayName)
                            .appCaptionStyle()
                            .foregroundColor(themeManager.primaryText)
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(themeManager.inputBackground)
                                Capsule()
                                    .fill(LinearGradient.ember)
                                    .frame(width: max(8, geo.size.width * CGFloat(sets) / CGFloat(maxSets)))
                            }
                        }
                        .frame(height: 10)
                        Text("\(sets)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(themeManager.secondaryText)
                            .frame(width: 26, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .appCard()
    }

    // MARK: - Strength trend

    private var chartExercise: Exercise? {
        if let name = chartExerciseName,
           let match = exercises.first(where: { $0.name == name }) {
            return match
        }
        // Default to the most recently trained exercise with enough history.
        return sessions
            .compactMap(\.exercise)
            .first { TrendPoint.series(for: $0).count >= 2 }
    }

    @ViewBuilder
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Strength Trend")
                Spacer()
                Menu {
                    ForEach(WorkoutLocation.allCases) { loc in
                        Section(loc.rawValue) {
                            ForEach(exercises.filter { $0.location == loc }, id: \.persistentModelID) { exercise in
                                Button(exercise.name) {
                                    chartExerciseName = exercise.name
                                    Haptics.shared.play(.selection)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(chartExercise?.name ?? "Pick exercise")
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.appAccent)
                }
            }

            if let exercise = chartExercise {
                let points = TrendPoint.series(for: exercise)
                if points.count >= 2 {
                    let isCardio = exercise.isCardio
                    let best = points.map(\.value).max() ?? 0

                    HStack(spacing: 8) {
                        ChipLabel(
                            text: isCardio
                                ? "Best \(TrainingEngine.formatWeight(best)) min"
                                : "Best est. 1RM \(TrainingEngine.formatWeight(best)) lb",
                            color: .appWarning
                        )
                        ChipLabel(text: exercise.location.rawValue, color: .appCardio)
                    }

                    // Home and gym sessions are different lifts in practice
                    // (equipment, machines) so they get their own lines.
                    TrendChart(points: points, yLabel: isCardio ? "Minutes" : "e1RM")

                    Text(isCardio
                         ? "Run time per session"
                         : "Estimated one-rep max per session (Epley)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(themeManager.secondaryText)
                } else {
                    Text("Log \(exercise.name) a couple more times to see a trend.")
                        .appBodyStyle()
                        .foregroundColor(themeManager.secondaryText)
                }
            } else {
                Text("Pick an exercise to see its trend.")
                    .appBodyStyle()
                    .foregroundColor(themeManager.secondaryText)
            }
        }
        .padding(16)
        .appCard()
    }

    // MARK: - Exercise list

    private var exerciseListCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionKicker(text: "Exercises")
                .padding(.bottom, 8)
            ForEach(exercises.filter { !$0.sessions.isEmpty }, id: \.persistentModelID) { exercise in
                NavigationLink {
                    ExerciseDetailView(exercise: exercise)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: exercise.isCardio ? "figure.run" : "dumbbell.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.appAccent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .appBodyStyle()
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.primaryText)
                            Text("\(exercise.sessions.count) session\(exercise.sessions.count == 1 ? "" : "s")")
                                .appCaptionStyle()
                                .foregroundColor(themeManager.secondaryText)
                        }
                        Spacer()
                        ChipLabel(text: exercise.location.rawValue,
                                  color: exercise.location == .home ? .appCardio : .appAccent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(themeManager.secondaryText)
                    }
                    .padding(.vertical, 10)
                }
                .hapticRow()
                if exercise.persistentModelID != exercises.filter({ !$0.sessions.isEmpty }).last?.persistentModelID {
                    Divider()
                }
            }
        }
        .padding(16)
        .appCard()
    }
}

// MARK: - Heat calendar day cell

private struct HeatDayCell: View {
    let date: Date
    let intensity: Double
    let trained: Bool
    let tookCreatine: Bool

    @EnvironmentObject var themeManager: ThemeManager

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(trained && intensity > 0.45 ? .white : themeManager.primaryText)
            Circle()
                .fill(tookCreatine ? Color.appCreatine : .clear)
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(trained ? Color.heat(max(intensity, 0.12)) : themeManager.inputBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isToday ? Color.appAccent : .clear, lineWidth: 2)
        )
    }
}
