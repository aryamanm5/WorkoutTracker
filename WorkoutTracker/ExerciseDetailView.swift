import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let exercise: Exercise

    var sortedSessions: [ExerciseSession] {
        exercise.sessions
            .sorted { $0.date > $1.date }
    }

    private var chartData: [ExerciseProgressPoint] {
        sortedSessions.compactMap { session in
            if exercise.isCardio {
                guard let runningTime = session.runningTime, runningTime > 0 else {
                    return nil
                }

                return ExerciseProgressPoint(date: session.date, value: runningTime)
            }

            guard let maxWeight = session.sets.map(\.weight).max(), maxWeight > 0 else {
                return nil
            }

            return ExerciseProgressPoint(date: session.date, value: maxWeight)
        }
        .sorted { $0.date < $1.date }
    }

    private var bestValue: Double? {
        chartData.map(\.value).max()
    }

    private var bestLabel: String {
        guard let bestValue else { return "-" }
        return exercise.isCardio ? String(format: "%.1f min", bestValue) : String(format: "%.1f lb", bestValue)
    }

    var body: some View {
        ZStack {
            themeManager.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryCard

                    if chartData.count > 1 {
                        chartCard
                    }

                    sessionHistory
                }
                .padding()
            }
        }
        .navigationTitle(exercise.name)
        .preferredColorScheme(themeManager.colorScheme)
    }

    var summaryCard: some View {
        HStack(spacing: 20) {
            ExerciseStat(label: "Sessions", value: "\(sortedSessions.count)", themeManager: themeManager)
            Divider()
                .background(themeManager.secondaryText.opacity(0.3))
            ExerciseStat(label: exercise.isCardio ? "Longest Run" : "Best", value: bestLabel, themeManager: themeManager)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(themeManager.cardBackground)
        .cornerRadius(16)
    }

    var chartCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(exercise.isCardio ? "Run Time Progression" : "Max Weight Progression")
                .font(.headline)
                .foregroundColor(themeManager.primaryText)

            Chart(chartData) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(exercise.isCardio ? "Minutes" : "Weight", point.value)
                )
                .symbol(Circle())
                .foregroundStyle(Color.appAccent)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(16)
    }

    var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Session History")
                .font(.headline)
                .foregroundColor(themeManager.primaryText)

            if sortedSessions.isEmpty {
                Text("No sessions logged yet.")
                    .foregroundColor(themeManager.secondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(themeManager.cardBackground)
                    .cornerRadius(12)
            } else {
                ForEach(sortedSessions) { session in
                    ExerciseSessionSummaryCard(session: session, themeManager: themeManager)
                }
            }
        }
    }
}

private struct ExerciseProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct ExerciseStat: View {
    let label: String
    let value: String
    let themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(themeManager.primaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExerciseSessionSummaryCard: View {
    let session: ExerciseSession
    let themeManager: ThemeManager

    var sortedSets: [LoggedSet] {
        session.sets.sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                        .foregroundColor(themeManager.primaryText)
                    Text(session.location.rawValue)
                        .font(.caption)
                        .foregroundColor(themeManager.secondaryText)
                }

                Spacer()

                if session.exercise?.isCardio == true, let runTime = session.runningTime {
                    Text("\(runTime, specifier: "%.1f") min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appAccent)
                } else if let maxWeight = sortedSets.map(\.weight).max() {
                    Text("\(maxWeight, specifier: "%.1f") lb max")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.appAccent)
                }
            }

            if session.exercise?.isCardio == true {
                HStack {
                    if let warmUpTime = session.warmUpTime {
                        MetricPill(label: "Warm-up", value: String(format: "%.1f min", warmUpTime), themeManager: themeManager)
                    }
                    if let runningSpeed = session.runningSpeed {
                        MetricPill(label: "Speed", value: String(format: "%.1f", runningSpeed), themeManager: themeManager)
                    }
                    if let intensityRating = session.intensityRating {
                        MetricPill(label: "Intensity", value: "\(intensityRating)/10", themeManager: themeManager)
                    }
                }
            } else if !session.machineSettings.isEmpty {
                Label(session.machineSettings, systemImage: "gearshape.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.secondaryText)
            }

            if session.exercise?.isCardio != true {
                ForEach(sortedSets) { set in
                    HStack {
                        Text("Set \(set.setNumber)")
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.secondaryText)
                        Spacer()
                        Text("\(set.reps) reps")
                            .foregroundColor(themeManager.primaryText)
                        Text("\(set.weight, specifier: "%.1f") lb")
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.primaryText)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(themeManager.cardBackground)
        .cornerRadius(12)
    }
}

private struct MetricPill: View {
    let label: String
    let value: String
    let themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(themeManager.secondaryText)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeManager.secondaryBackground)
        .cornerRadius(8)
    }
}
