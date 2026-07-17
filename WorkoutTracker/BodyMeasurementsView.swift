import SwiftUI
import SwiftData
import Charts

/// How the Measure page organizes its sites: one chart card per site,
/// stacked under Torso / Arms / Legs headings.
private struct MeasurementGroupSpec: Identifiable {
    let title: String
    let icon: String
    let sites: [MeasurementSite]
    var id: String { title }

    static let all: [MeasurementGroupSpec] = [
        MeasurementGroupSpec(
            title: "Torso", icon: "figure.core.training",
            sites: [.neck, .shoulders, .chest, .waist, .hips]),
        MeasurementGroupSpec(
            title: "Arms", icon: "figure.strengthtraining.traditional",
            sites: [.leftArm, .rightArm, .leftForearm, .rightForearm]),
        MeasurementGroupSpec(
            title: "Legs", icon: "figure.walk",
            sites: [.leftQuad, .rightQuad, .leftCalf, .rightCalf])
    ]
}

/// The Measure page of the Body tab: a stack of per-site trend charts grouped
/// by body region. Every card can log a new point, and expanding a card lists
/// its entries for editing — value, notes, and date included.
struct BodyMeasurementsSection: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var addSite: MeasurementSite?
    @State private var measurementToEdit: BodyMeasurement?
    @State private var measurementToDelete: BodyMeasurement?
    @State private var expandedSites: Set<MeasurementSite> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(MeasurementGroupSpec.all) { group in
                VStack(alignment: .leading, spacing: 12) {
                    Label(group.title, systemImage: group.icon)
                        .appHeadingStyle()
                        .foregroundColor(Color.appPrimaryText)

                    ForEach(group.sites) { site in
                        SiteMeasurementCard(
                            site: site,
                            entries: entries(for: site),
                            isExpanded: expandedSites.contains(site),
                            onAdd: { addSite = site },
                            onToggleExpand: { toggleExpanded(site) },
                            onEdit: { measurementToEdit = $0 },
                            onDelete: { measurementToDelete = $0 }
                        )
                    }
                }
            }
        }
        .sheet(item: $addSite) { site in
            MeasurementFormSheet(measurement: nil, initialSite: site)
                .themedPresentation()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $measurementToEdit) { measurement in
            MeasurementFormSheet(measurement: measurement, initialSite: measurement.site)
                .themedPresentation()
                .presentationDetents([.medium, .large])
        }
        .deleteConfirmation("Delete this measurement?", item: $measurementToDelete, context: context) {
            "This removes the \($0.site.displayName.lowercased()) entry from \($0.date.formatted(date: .abbreviated, time: .omitted))."
        }
    }

    /// A site's entries, newest first (`measurements` is already sorted).
    private func entries(for site: MeasurementSite) -> [BodyMeasurement] {
        measurements.filter { $0.site == site }
    }

    private func toggleExpanded(_ site: MeasurementSite) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSites.contains(site) {
                expandedSites.remove(site)
            } else {
                expandedSites.insert(site)
            }
        }
    }
}

// MARK: - Site card

/// One site's card: name and latest number up top, its trend chart when
/// there's one to draw, and an expandable entry list for edits.
private struct SiteMeasurementCard: View {
    let site: MeasurementSite
    /// Newest first.
    let entries: [BodyMeasurement]
    let isExpanded: Bool
    let onAdd: () -> Void
    let onToggleExpand: () -> Void
    let onEdit: (BodyMeasurement) -> Void
    let onDelete: (BodyMeasurement) -> Void

    private var latest: BodyMeasurement? { entries.first }

    private var delta: Double? {
        entries.count > 1 ? entries[0].value - entries[1].value : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if entries.count >= 2 {
                chart
            } else if entries.count == 1 {
                Text("One entry — log another to see the trend.")
                    .appCaptionStyle()
                    .foregroundColor(Color.appSecondaryText)
            }

            if isExpanded {
                entryList
            }

            if !entries.isEmpty {
                expandToggle
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appPrimaryText)
                if let latest {
                    Text("Updated \(latest.date.formatted(.relative(presentation: .named)))")
                        .appCaptionStyle()
                        .foregroundColor(Color.appSecondaryText)
                } else {
                    Text("No entries yet")
                        .appCaptionStyle()
                        .foregroundColor(Color.appSecondaryText)
                }
            }

            Spacer()

            if let latest {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(latest.value.formatted())
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Color.appPrimaryText)
                        Text("in")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appSecondaryText)
                    }
                    if let delta, abs(delta) >= 0.05 {
                        HStack(spacing: 2) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%+.2f", delta))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(delta > 0 ? .appSuccess : .appCardio)
                    }
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appAccent)
            }
            .hapticButton()
            .accessibilityLabel("Add \(site.displayName)")
        }
    }

    // MARK: Chart

    /// Oldest → newest for plotting.
    private var chartEntries: [BodyMeasurement] {
        entries.sorted { $0.date < $1.date }
    }

    /// Y range hugs the data with a touch of headroom: tape measurements move
    /// by fractions of an inch, so a zero-based axis would flatten every
    /// trend into a straight line.
    private var chartDomain: ClosedRange<Double> {
        let values = chartEntries.map(\.value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max((maxValue - minValue) * 0.25, 0.4)
        return (minValue - padding)...(maxValue + padding)
    }

    private var chart: some View {
        Chart {
            ForEach(chartEntries, id: \.persistentModelID) { entry in
                AreaMark(
                    x: .value("Date", entry.date),
                    y: .value("Inches", entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appAccent.opacity(0.22), Color.appAccent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", entry.date),
                    y: .value("Inches", entry.value)
                )
                .foregroundStyle(Color.appAccent)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date),
                    y: .value("Inches", entry.value)
                )
                .foregroundStyle(Color.appAccent)
                .symbolSize(20)
            }
        }
        .chartYScale(domain: chartDomain)
        .chartPlotStyle { plot in
            plot.clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Color.appCardBorder.opacity(0.4))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(0...1))))
                            .font(.system(size: 10))
                            .foregroundColor(Color.appSecondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 10))
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .frame(height: 120)
        .padding(.top, 2)
    }

    // MARK: Entries

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entries, id: \.persistentModelID) { entry in
                Button {
                    onEdit(entry)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.value.formatted()) in")
                                .appBodyStyle()
                                .fontWeight(.semibold)
                                .foregroundColor(Color.appPrimaryText)
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .appCaptionStyle()
                                .foregroundColor(Color.appSecondaryText)
                        }
                        Spacer()
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .appCaptionStyle()
                                .foregroundColor(Color.appSecondaryText)
                                .lineLimit(1)
                        }
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appSecondaryText)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .hapticRow()
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
                }
                if entry.persistentModelID != entries.last?.persistentModelID {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 4)
        .background(Color.appInputBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var expandToggle: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                Text(isExpanded
                     ? "Hide entries"
                     : "Edit \(entries.count) \(entries.count == 1 ? "entry" : "entries")")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.appAccent)
        }
        .hapticButton(.tap, pressScale: 0.98)
        .accessibilityLabel("\(site.displayName) entries")
    }
}

// MARK: - Add / edit sheet

/// One sheet for both flows: pass a measurement to edit it, or nil to log a
/// new one. Every field — site, value, date, notes — stays editable.
struct MeasurementFormSheet: View {
    let measurement: BodyMeasurement?
    let initialSite: MeasurementSite

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var site: MeasurementSite = .chest
    @State private var valueText = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var loaded = false

    private var parsedValue: Double? {
        guard let value = Double(userInput: valueText), value > 0, value < 200 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Site")
                            .appBodyStyle()
                            .foregroundColor(Color.appPrimaryText)
                        let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                            ForEach(MeasurementSite.allCases) { candidate in
                                let isOn = site == candidate
                                Button {
                                    site = candidate
                                } label: {
                                    Text(candidate.displayName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(isOn ? .white : Color.appPrimaryText)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isOn ? AnyShapeStyle(Color.appAccent) : AnyShapeStyle(Color.appInputBackground))
                                        .clipShape(Capsule())
                                }
                                .hapticButton(.selection, pressScale: 0.94)
                            }
                        }
                    }

                    HStack {
                        TextField("Inches", text: $valueText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .appInputStyle()
                        Text("in")
                            .appHeadingStyle()
                            .foregroundColor(Color.appSecondaryText)
                    }

                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .tint(.appAccent)
                        .foregroundColor(Color.appPrimaryText)

                    TextField("Notes (optional)", text: $notes)
                        .appInputStyle()

                    Button(measurement == nil ? "Save Measurement" : "Save Changes") { save() }
                        .buttonStyle(EmberButtonStyle())
                        .disabled(parsedValue == nil)
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(measurement == nil ? "Log Measurement" : "Edit Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .dismissableKeyboard()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let measurement {
                    site = measurement.site
                    valueText = measurement.value.formatted()
                    date = measurement.date
                    notes = measurement.notes
                } else {
                    site = initialSite
                }
            }
        }
    }

    private func save() {
        guard let value = parsedValue else { return }
        if let measurement {
            measurement.site = site
            measurement.value = value
            measurement.date = date
            measurement.notes = notes
        } else {
            context.insert(BodyMeasurement(date: date, site: site, value: value, notes: notes))
        }
        try? context.save()
        Haptics.shared.play(.setLogged)
        dismiss()
    }
}
