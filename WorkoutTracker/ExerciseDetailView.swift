import SwiftUI
import Charts

/// Per-exercise analytics: e1RM trend, bests, and full session history.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject var themeManager: ThemeManager

    private var sortedSessions: [ExerciseSession] {
        exercise.sessions.sorted { $0.date > $1.date }
    }

    private var chartData: [TrendPoint] {
        TrendPoint.series(for: exercise)
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
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: exercise.isCardio ? "Run Time" : "Estimated 1RM")
            // Legacy sessions logged at the other location plot as their own
            // line — home and gym numbers aren't comparable.
            TrendChart(points: chartData)
        }
        .padding(16)
        .appCard()
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
