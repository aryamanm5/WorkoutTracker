import SwiftUI
import Charts

/// Per-exercise analytics: e1RM trend, bests, and full session history.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager

    private var sortedSessions: [ExerciseSession] {
        exercise.sessions.sorted { $0.date > $1.date }
    }

    private struct ProgressPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let location: String
    }

    private var chartData: [ProgressPoint] {
        exercise.sessions
            .sorted { $0.date < $1.date }
            .compactMap { session in
                if exercise.isCardio {
                    guard let time = session.runningTime, time > 0 else { return nil }
                    return ProgressPoint(date: session.date, value: time, location: session.location.rawValue)
                }
                let e1rm = TrainingEngine.bestOneRepMax(in: session)
                guard e1rm > 0 else { return nil }
                return ProgressPoint(date: session.date, value: e1rm, location: session.location.rawValue)
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryRow

                if chartData.count >= 2 {
                    chartCard
                }

                sessionHistory
            }
            .padding(16)
        }
        .background(themeManager.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summaryRow: some View {
        let best = chartData.map(\.value).max() ?? 0
        let topWeight = exercise.sessions.flatMap(\.sets).map(\.weight).max() ?? 0

        return HStack(spacing: 12) {
            StatTile(
                icon: "number",
                iconColor: .appCardio,
                value: "\(exercise.sessions.count)",
                label: "Sessions"
            )
            if exercise.isCardio {
                StatTile(
                    icon: "stopwatch.fill",
                    iconColor: .appAccent,
                    value: best > 0 ? TrainingEngine.formatWeight(best) : "—",
                    label: "Longest Run"
                )
            } else {
                StatTile(
                    icon: "trophy.fill",
                    iconColor: .appWarning,
                    value: best > 0 ? TrainingEngine.formatWeight(best) : "—",
                    label: "Best est. 1RM"
                )
                StatTile(
                    icon: "scalemass.fill",
                    iconColor: .appAccent,
                    value: topWeight > 0 ? TrainingEngine.formatWeight(topWeight) : "—",
                    label: "Top Weight"
                )
            }
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        let locations = Array(Set(chartData.map(\.location))).sorted()
        let splitByLocation = locations.count > 1
        let singleColor = locations.first == WorkoutLocation.home.rawValue ? Color.appCardio : Color.appAccent

        return VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: exercise.isCardio ? "Run Time" : "Estimated 1RM")
            // Legacy sessions logged at the other location plot as their own
            // line — home and gym numbers aren't comparable.
            Chart(chartData) { point in
                if !splitByLocation {
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [singleColor.opacity(0.35), singleColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Location", point.location))
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(by: .value("Location", point.location))
                .symbolSize(30)
            }
            .chartForegroundStyleScale(
                domain: locations,
                range: locations.map { $0 == WorkoutLocation.home.rawValue ? Color.appCardio : Color.appAccent }
            )
            .chartLegend(splitByLocation ? .visible : .hidden)
            .chartYScale(domain: chartDomain)
            .frame(height: 180)
        }
        .padding(16)
        .appCard()
    }

    private var chartDomain: ClosedRange<Double> {
        let values = chartData.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.15, 5)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    // MARK: - History

    private var sessionHistory: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "History")
            ForEach(sortedSessions, id: \.persistentModelID) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    SessionCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
