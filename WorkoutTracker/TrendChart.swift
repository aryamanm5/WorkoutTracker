import SwiftUI
import Charts

/// One point on an exercise's progress line: e1RM for strength, run-time
/// minutes for cardio. Shared by the Insights strength trend and the
/// per-exercise detail chart.
struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let location: String

    /// Progress series for an exercise, oldest first. Sessions with no
    /// usable value (zero e1RM, missing run time) are dropped.
    static func series(for exercise: Exercise) -> [TrendPoint] {
        exercise.sessions
            .sorted { $0.date < $1.date }
            .compactMap { session in
                if exercise.isCardio {
                    guard let time = session.runningTime, time > 0 else { return nil }
                    return TrendPoint(date: session.date, value: time, location: session.location.rawValue)
                }
                let e1rm = TrainingEngine.bestOneRepMax(in: session)
                guard e1rm > 0 else { return nil }
                return TrendPoint(date: session.date, value: e1rm, location: session.location.rawValue)
            }
    }
}

/// The ember progress line: an area+line+point chart that splits home and
/// gym history into separate lines (they aren't comparable). Callers gate on
/// `points.count >= 2` before showing it.
struct TrendChart: View {
    let points: [TrendPoint]
    var yLabel: String = "Value"

    private var domain: ClosedRange<Double> {
        let values = points.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.15, 5)
        return max(0, minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        let locations = Array(Set(points.map(\.location))).sorted()
        let splitByLocation = locations.count > 1
        let singleColor = locations.first == WorkoutLocation.home.rawValue ? Color.appCardio : Color.appAccent

        Chart(points) { point in
            if !splitByLocation {
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(yLabel, point.value)
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
                y: .value(yLabel, point.value)
            )
            .foregroundStyle(by: .value("Location", point.location))
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", point.date),
                y: .value(yLabel, point.value)
            )
            .foregroundStyle(by: .value("Location", point.location))
            .symbolSize(30)
        }
        .chartForegroundStyleScale(
            domain: locations,
            range: locations.map { $0 == WorkoutLocation.home.rawValue ? Color.appCardio : Color.appAccent }
        )
        .chartLegend(splitByLocation ? .visible : .hidden)
        .chartYScale(domain: domain)
        // Force calendar-date labels — with a narrow date span Swift Charts
        // otherwise defaults the axis to clock times.
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 180)
    }
}
