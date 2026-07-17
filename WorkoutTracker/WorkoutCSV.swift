import Foundation
import SwiftData

/// Builds and parses the app's CSV backup: workout sessions with their sets,
/// body measurements, and body weight history, in one file. Lives outside the
/// Settings screen so the round-trip can be unit-tested.
@MainActor
struct WorkoutCSV {
    let context: ModelContext

    struct ImportSummary {
        var sessions = 0
        var sets = 0
        var weights = 0
        var measurements = 0
        var skipped = 0
    }

    /// POSIX locale so 12/24-hour overrides and non-Gregorian device
    /// calendars can't corrupt the exported dates. Seconds precision keeps
    /// distinct same-minute sessions distinct on re-import.
    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private let dateFormatter = makeFormatter("yyyy-MM-dd HH:mm:ss")
    /// Older exports only carried minute precision.
    private let legacyDateFormatter = makeFormatter("yyyy-MM-dd HH:mm")

    // MARK: - Export

    func exportString() -> String {
        var csvString = "Date,Exercise,Type,IsCardio,Location,SetNumber,Reps,Weight(lbs),Difficulty,RestTime(s),SetNotes,MachineSettings,WarmUp(min),Run(min),CoolDown(min),Speed,Intensity,SessionNotes\n"

        // Fetch fresh with relationships faulted in
        let descriptor = FetchDescriptor<ExerciseSession>(
            sortBy: [SortDescriptor(\ExerciseSession.date)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        for session in sessions {
            guard let exercise = session.exercise else { continue }

            let dateStr = dateFormatter.string(from: session.date)
            let exName = escapeCSV(exercise.name)
            let exType = exercise.type.rawValue
            let isCardio = exercise.isCardio ? "Yes" : "No"
            let location = escapeCSV(session.location.rawValue)
            let settings = escapeCSV(session.machineSettings)
            let sessionNotes = escapeCSV(session.notes)

            if exercise.isCardio {
                let wUp   = session.warmUpTime.map    { String($0) } ?? ""
                let run   = session.runningTime.map   { String($0) } ?? ""
                let cDown = session.coolDownTime.map  { String($0) } ?? ""
                let speed = session.runningSpeed.map  { String($0) } ?? ""
                let intensity = session.intensityRating.map { String($0) } ?? ""

                csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),,,,,,,\(settings),\(wUp),\(run),\(cDown),\(speed),\(intensity),\(sessionNotes)\n")
            } else {
                let sortedSets = session.sets.sorted { $0.setNumber < $1.setNumber }

                if sortedSets.isEmpty {
                    csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),,,,,,,\(settings),,,,,,\(sessionNotes)\n")
                } else {
                    for set in sortedSets {
                        let setNotes  = escapeCSV(set.notes)
                        let restTime  = set.restTimeSeconds.map { String($0) } ?? ""
                        csvString.append("\(dateStr),\(exName),\(exType),\(isCardio),\(location),\(set.setNumber),\(set.reps),\(set.weight),\(set.difficulty),\(restTime),\(setNotes),\(settings),,,,,,\(sessionNotes)\n")
                    }
                }
            }
        }

        // Measurements come BEFORE body weight: the weight parser reads to the
        // end of the file, so anything after it would be swallowed.
        let measurementDescriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\BodyMeasurement.date)]
        )
        if let bodyMeasurements = try? context.fetch(measurementDescriptor), !bodyMeasurements.isEmpty {
            csvString.append("\n\nBody Measurements\nDate,Site,Value(in),Notes\n")
            for measurement in bodyMeasurements {
                let dateStr = dateFormatter.string(from: measurement.date)
                let notes = escapeCSV(measurement.notes)
                csvString.append("\(dateStr),\(measurement.siteRawValue),\(measurement.value),\(notes)\n")
            }
        }

        let weightDescriptor = FetchDescriptor<BodyWeightEntry>(
            sortBy: [SortDescriptor(\BodyWeightEntry.date, order: .reverse)]
        )
        if let weightEntries = try? context.fetch(weightDescriptor), !weightEntries.isEmpty {
            csvString.append("\n\nBody Weight History\nDate,Weight(lbs),Notes\n")
            for entry in weightEntries {
                let dateStr = dateFormatter.string(from: entry.date)
                let notes = escapeCSV(entry.notes)
                csvString.append("\(dateStr),\(entry.weight),\(notes)\n")
            }
        }

        return csvString
    }

    private func escapeCSV(_ string: String) -> String {
        var result = string.replacingOccurrences(of: "\"", with: "\"\"")
        if result.contains(",") || result.contains("\n") || result.contains("\"") {
            result = "\"\(result)\""
        }
        return result
    }

    // MARK: - Import

    func importString(_ csvString: String) -> ImportSummary {
        let rows = parseCSVRows(csvString)
        var index = 0
        var summary = ImportSummary()

        func parseDate(_ text: String) -> Date? {
            dateFormatter.date(from: text) ?? legacyDateFormatter.date(from: text)
        }

        // Look up exercises against the live context and remember what
        // already exists so re-importing an export is a no-op.
        var exerciseCache: [String: Exercise] = [:]
        var existingSessionKeys = Set<String>()
        var existingWeightKeys = Set<String>()
        var existingMeasurementKeys = Set<String>()

        if let storedExercises = try? context.fetch(FetchDescriptor<Exercise>()) {
            for exercise in storedExercises {
                exerciseCache["\(exercise.name.lowercased())|\(exercise.location.rawValue)"] = exercise
                for session in exercise.sessions {
                    existingSessionKeys.insert(sessionDedupKey(exerciseName: exercise.name, date: session.date))
                }
            }
        }
        if let storedWeights = try? context.fetch(FetchDescriptor<BodyWeightEntry>()) {
            for entry in storedWeights {
                existingWeightKeys.insert(weightDedupKey(date: entry.date, weight: entry.weight))
            }
        }
        if let storedMeasurements = try? context.fetch(FetchDescriptor<BodyMeasurement>()) {
            for measurement in storedMeasurements {
                existingMeasurementKeys.insert(measurementDedupKey(
                    date: measurement.date, site: measurement.site, value: measurement.value))
            }
        }

        while index < rows.count {
            let row = rows[index]
            if row.first == "Date", row.contains("Exercise") {
                let header = headerMap(row)
                index += 1
                var importedSessions: [String: ExerciseSession] = [:]

                while index < rows.count {
                    let workoutRow = rows[index]
                    if workoutRow.isEmpty || workoutRow.first == "Body Weight History"
                        || workoutRow.first == "Body Measurements" {
                        break
                    }
                    guard let dateText = value(in: workoutRow, header: header, column: "Date"),
                          let date = parseDate(dateText),
                          let exerciseName = value(in: workoutRow, header: header, column: "Exercise"),
                          !exerciseName.isEmpty,
                          let typeText = value(in: workoutRow, header: header, column: "Type") else {
                        index += 1
                        continue
                    }

                    if existingSessionKeys.contains(sessionDedupKey(exerciseName: exerciseName, date: date)) {
                        summary.skipped += 1
                        index += 1
                        continue
                    }

                    let workoutType = WorkoutType(rawValue: typeText) ?? .push
                    let isCardio = value(in: workoutRow, header: header, column: "IsCardio") == "Yes"
                    let locationText = value(in: workoutRow, header: header, column: "Location") ?? WorkoutLocation.gym.rawValue
                    let location = WorkoutLocation.from(stored: locationText)
                    let exercise = findOrCreateExercise(named: exerciseName, type: workoutType, isCardio: isCardio, location: location, cache: &exerciseCache)
                    let machineSettings = value(in: workoutRow, header: header, column: "MachineSettings") ?? ""
                    let sessionNotes = value(in: workoutRow, header: header, column: "SessionNotes") ?? ""
                    let sessionKey = "\(date.timeIntervalSince1970)-\(exerciseName.lowercased())-\(machineSettings)-\(sessionNotes)"
                    let session = importedSessions[sessionKey] ?? {
                        let newSession = ExerciseSession(
                            date: date,
                            machineSettings: machineSettings,
                            totalSets: 0,
                            notes: sessionNotes,
                            location: location,
                            warmUpTime: doubleValue(in: workoutRow, header: header, column: "WarmUp(min)"),
                            runningTime: doubleValue(in: workoutRow, header: header, column: "Run(min)"),
                            coolDownTime: doubleValue(in: workoutRow, header: header, column: "CoolDown(min)"),
                            runningSpeed: doubleValue(in: workoutRow, header: header, column: "Speed"),
                            intensityRating: intValue(in: workoutRow, header: header, column: "Intensity")
                        )
                        context.insert(newSession)
                        newSession.exercise = exercise
                        importedSessions[sessionKey] = newSession
                        summary.sessions += 1
                        return newSession
                    }()

                    if let setNumber = intValue(in: workoutRow, header: header, column: "SetNumber") {
                        let loggedSet = LoggedSet(
                            setNumber: setNumber,
                            reps: intValue(in: workoutRow, header: header, column: "Reps") ?? 0,
                            weight: doubleValue(in: workoutRow, header: header, column: "Weight(lbs)") ?? 0,
                            notes: value(in: workoutRow, header: header, column: "SetNotes") ?? "",
                            difficulty: intValue(in: workoutRow, header: header, column: "Difficulty") ?? 3,
                            restTimeSeconds: intValue(in: workoutRow, header: header, column: "RestTime(s)")
                        )
                        context.insert(loggedSet)
                        loggedSet.session = session
                        session.totalSets += 1
                        summary.sets += 1
                    }

                    index += 1
                }
            } else if row.first == "Date", row.contains("Site") {
                let header = headerMap(row)
                index += 1

                while index < rows.count {
                    let measurementRow = rows[index]
                    if measurementRow.isEmpty {
                        index += 1
                        continue
                    }
                    if measurementRow.first == "Body Weight History" {
                        break
                    }

                    // A row with an unrecognized site is skipped, never
                    // defaulted — silently filing a typo under "chest" would
                    // corrupt the timeline.
                    guard let dateText = value(in: measurementRow, header: header, column: "Date"),
                          let date = parseDate(dateText),
                          let siteText = value(in: measurementRow, header: header, column: "Site"),
                          let site = MeasurementSite.allCases.first(where: {
                              $0.rawValue == siteText
                                  || $0.displayName.caseInsensitiveCompare(siteText) == .orderedSame
                          }),
                          let measurementValue = doubleValue(in: measurementRow, header: header, column: "Value(in)") else {
                        index += 1
                        continue
                    }

                    let key = measurementDedupKey(date: date, site: site, value: measurementValue)
                    if existingMeasurementKeys.contains(key) {
                        summary.skipped += 1
                        index += 1
                        continue
                    }

                    let measurement = BodyMeasurement(
                        date: date,
                        site: site,
                        value: measurementValue,
                        notes: value(in: measurementRow, header: header, column: "Notes") ?? ""
                    )
                    context.insert(measurement)
                    existingMeasurementKeys.insert(key)
                    summary.measurements += 1
                    index += 1
                }
            } else if row.first == "Date", row.contains("Weight(lbs)") {
                let header = headerMap(row)
                index += 1

                while index < rows.count {
                    let weightRow = rows[index]
                    guard !weightRow.isEmpty else {
                        index += 1
                        continue
                    }

                    guard let dateText = value(in: weightRow, header: header, column: "Date"),
                          let date = parseDate(dateText),
                          let weight = doubleValue(in: weightRow, header: header, column: "Weight(lbs)") else {
                        // Skip the malformed row but keep importing the rest.
                        index += 1
                        continue
                    }

                    let weightKey = weightDedupKey(date: date, weight: weight)
                    if existingWeightKeys.contains(weightKey) {
                        summary.skipped += 1
                        index += 1
                        continue
                    }

                    let entry = BodyWeightEntry(
                        date: date,
                        weight: weight,
                        notes: value(in: weightRow, header: header, column: "Notes") ?? ""
                    )
                    context.insert(entry)
                    existingWeightKeys.insert(weightKey)
                    summary.weights += 1
                    index += 1
                }
            } else {
                index += 1
            }
        }

        return summary
    }

    // MARK: - Dedup keys

    /// Dedup compares at minute precision: stored dates carry sub-second
    /// precision and legacy exports only carry minutes, so exact-timestamp
    /// keys never matched and every re-import duplicated the whole file.
    private func sessionDedupKey(exerciseName: String, date: Date) -> String {
        "\(exerciseName.lowercased())|\(Int(date.timeIntervalSince1970 / 60))"
    }

    private func weightDedupKey(date: Date, weight: Double) -> String {
        "\(Int(date.timeIntervalSince1970 / 60))|\(weight)"
    }

    private func measurementDedupKey(date: Date, site: MeasurementSite, value: Double) -> String {
        "\(Int(date.timeIntervalSince1970 / 60))|\(site.rawValue)|\(value)"
    }

    private func findOrCreateExercise(named name: String, type: WorkoutType, isCardio: Bool, location: WorkoutLocation, cache: inout [String: Exercise]) -> Exercise {
        // Home and gym libraries are separate, so the same name can exist
        // once per location.
        let key = "\(name.lowercased())|\(location.rawValue)"
        if let existing = cache[key] {
            // Never mutate an existing library entry from imported rows — an
            // old export would silently undo later re-categorization.
            return existing
        }

        let exercise = Exercise(name: name, type: type, isCardio: isCardio, location: location)
        context.insert(exercise)
        cache[key] = exercise
        return exercise
    }

    // MARK: - Row parsing

    private func headerMap(_ row: [String]) -> [String: Int] {
        // First occurrence wins — `uniqueKeysWithValues` would crash the app
        // on a hand-edited file with a repeated column name.
        Dictionary(row.enumerated().map { ($0.element, $0.offset) },
                   uniquingKeysWith: { first, _ in first })
    }

    private func value(in row: [String], header: [String: Int], column: String) -> String? {
        guard let index = header[column], row.indices.contains(index) else { return nil }
        let value = row[index]
        return value.isEmpty ? nil : value
    }

    private func intValue(in row: [String], header: [String: Int], column: String) -> Int? {
        value(in: row, header: header, column: column).flatMap(Int.init)
    }

    private func doubleValue(in row: [String], header: [String: Int], column: String) -> Double? {
        value(in: row, header: header, column: column).flatMap(Double.init)
    }

    private func parseCSVRows(_ csvString: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isInsideQuotes = false
        var iterator = csvString.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isInsideQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append(next)
                    } else {
                        isInsideQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == ",", !isInsideQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !isInsideQuotes {
                row.append(field)
                if row.contains(where: { !$0.isEmpty }) {
                    rows.append(row)
                } else {
                    rows.append([])
                }
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }
}
