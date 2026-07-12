import Foundation

/// Pure logic for the adaptive coaching features: graded muscle recovery,
/// split recommendation, automatic progression, e1RM and PR detection,
/// streaks and volume. Views feed in SwiftData rows; nothing here mutates.
enum TrainingEngine {

    // MARK: - Recovery model

    /// Hours a strength stimulus takes to fully dissipate.
    static let strengthRecoveryHours: Double = 72
    /// Cardio recovers faster than lifting.
    static let cardioRecoveryHours: Double = 40

    enum RecoveryStatus: String {
        case fatigued = "Fatigued"
        case recovering = "Recovering"
        case nearlyFresh = "Nearly Fresh"
        case fresh = "Fresh"

        static func from(fatigue: Double) -> RecoveryStatus {
            switch fatigue {
            case 0.66...: return .fatigued
            case 0.33..<0.66: return .recovering
            case 0.001..<0.33: return .nearlyFresh
            default: return .fresh
            }
        }
    }

    /// Per-muscle fatigue in 0...1, decaying linearly since each session.
    /// A muscle's fatigue is the strongest remaining stimulus, not a sum —
    /// two back-to-back chest days shouldn't read as 200% fatigued.
    static func muscleFatigue(sessions: [ExerciseSession], now: Date = Date()) -> [TargetMuscle: Double] {
        var fatigue: [TargetMuscle: Double] = [:]

        for session in sessions {
            guard let exercise = session.exercise else { continue }
            let hoursAgo = now.timeIntervalSince(session.date) / 3600
            guard hoursAgo >= 0 else { continue }

            let window = exercise.isCardio ? cardioRecoveryHours : strengthRecoveryHours
            let decay = max(0, 1 - hoursAgo / window)
            guard decay > 0 else { continue }

            let magnitude: Double
            if exercise.isCardio {
                magnitude = 0.6
            } else {
                let setCount = max(session.sets.count, 1)
                let avgDifficulty = session.sets.isEmpty
                    ? 3.0
                    : Double(session.sets.map(\.difficulty).reduce(0, +)) / Double(session.sets.count)
                // 3 hard sets ≈ full stimulus; easy sessions leave less behind.
                let volumeFactor = min(1.0, 0.45 + 0.18 * Double(setCount))
                let effortFactor = min(1.2, max(0.7, avgDifficulty / 3.0))
                magnitude = min(1.0, volumeFactor * effortFactor)
            }

            let contribution = magnitude * decay
            for muscle in exercise.targetMuscles where muscle != .cardio {
                fatigue[muscle] = max(fatigue[muscle] ?? 0, contribution)
            }
        }
        return fatigue
    }

    // MARK: - Adaptive split recommendation

    struct SplitRecommendation {
        let type: WorkoutType
        let reason: String
    }

    /// Recommends today's focus from a fixed weekly split (Push Mon/Thu,
    /// Pull Tue/Fri, Legs Wed/Sat, rest Sunday) — but swaps to a fresher
    /// split when the scheduled muscles are still clearly fatigued.
    static func recommendation(sessions: [ExerciseSession], now: Date = Date()) -> SplitRecommendation {
        let weekday = Calendar.current.component(.weekday, from: now)

        let scheduled: WorkoutType
        switch weekday {
        case 2, 5: scheduled = .push  // Mon, Thu
        case 3, 6: scheduled = .pull  // Tue, Fri
        case 4, 7: scheduled = .legs  // Wed, Sat
        default: scheduled = .rest    // Sun
        }

        let fatigue = muscleFatigue(sessions: sessions, now: now)

        func averageFatigue(for type: WorkoutType) -> Double {
            let muscles = MuscleCatalog.defaultTargets(for: type)
            guard !muscles.isEmpty else { return 0 }
            return muscles.map { fatigue[$0] ?? 0 }.reduce(0, +) / Double(muscles.count)
        }

        if scheduled == .rest {
            return SplitRecommendation(
                type: .rest,
                reason: "Sunday is your scheduled rest day — recover up for the week ahead."
            )
        }

        let scheduledFatigue = averageFatigue(for: scheduled)

        // If the scheduled muscles are still beat up (e.g. you trained them
        // off-schedule yesterday), point the day at the freshest split instead.
        if scheduledFatigue > 0.5 {
            let alternative = [WorkoutType.push, .pull, .legs]
                .filter { $0 != scheduled }
                .min { averageFatigue(for: $0) < averageFatigue(for: $1) }
            if let alternative, averageFatigue(for: alternative) < scheduledFatigue - 0.2 {
                return SplitRecommendation(
                    type: alternative,
                    reason: "Your \(scheduled.rawValue.lowercased()) muscles are still recovering, so today swap to \(alternative.rawValue.lowercased()) — \(focusSummary(for: alternative).lowercased()) are fresher."
                )
            }
        }

        return SplitRecommendation(
            type: scheduled,
            reason: "\(focusSummary(for: scheduled)) — today's scheduled \(scheduled.rawValue.lowercased()) day."
        )
    }

    private static func focusSummary(for type: WorkoutType) -> String {
        switch type {
        case .push: return "Chest, shoulders & triceps"
        case .pull: return "Back & biceps"
        case .legs: return "Quads, hamstrings & glutes"
        case .rest: return "Everything"
        }
    }

    // MARK: - Progression

    /// What the coach is progressing you toward. Hypertrophy runs double
    /// progression (8–12 reps, weight moves only when every set tops the
    /// range); strength runs linear progression (5+ clean reps on all sets
    /// adds weight every session, StrongLifts-style).
    enum TrainingGoal: String, CaseIterable, Identifiable {
        case hypertrophy
        case strength

        var id: String { rawValue }

        var displayName: String {
            self == .hypertrophy ? "Hypertrophy" : "Strength"
        }

        /// Resolved from Settings at decision time so every existing call
        /// site picks up the user's goal without threading it through views.
        static var current: TrainingGoal {
            TrainingGoal(rawValue: UserDefaults.standard.string(forKey: "trainingGoal") ?? "") ?? .hypertrophy
        }
    }

    /// Top of the hypertrophy rep range: clear this on every set to add weight.
    static let hypertrophyRepTop = 12
    /// Strength prescription: all sets need at least this many clean reps.
    static let strengthRepFloor = 5

    enum ProgressionKind {
        case increase
        case hold
        case decrease
        case manual
    }

    struct ProgressionAdvice {
        let kind: ProgressionKind
        let weight: Double
        let reason: String
    }

    /// Coach's plate jump for one progression step, sized to the equipment
    /// (StrongLifts / Starting Strength convention): isolation moves creep up
    /// by 2.5 lb, deadlifts and pin-stack machines take 10 lb jumps, and
    /// everything else — barbell, dumbbell, cable compounds — moves in 5 lb
    /// steps, the smallest jump most gyms actually stock.
    static func weightIncrement(for exercise: Exercise) -> Double {
        if isIsolation(exercise.name) { return 2.5 }
        let n = exercise.name.lowercased()
        if n.contains("deadlift") || n.contains("machine") { return 10 }
        return 5
    }

    /// Assisted moves (assisted pull-up/dip/chin-up) load the machine's help,
    /// so more weight means an *easier* set. Progression runs in reverse.
    static func isAssisted(_ name: String) -> Bool {
        name.lowercased().contains("assist")
    }

    /// Small single-joint moves where a 5 lb jump is a huge relative leap.
    static func isIsolation(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["curl", "raise", "lateral", "fly", "flye", "extension", "pushdown",
                "kickback", "face pull", "shrug", "calf", "adductor", "abductor",
                "crunch", "oblique", "wrist", "forearm"]
            .contains { n.contains($0) }
    }

    /// Rounds a suggested weight to the exercise's plate increment.
    static func roundToIncrement(_ weight: Double, increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment).rounded() * increment
    }

    /// Suggests the next working weight from recent performance.
    /// A manual target saved on the exercise always wins. Because home and
    /// gym keep separate exercise libraries, an exercise's history is
    /// inherently one location's history — home dumbbell work never inflates
    /// gym machine advice.
    static func progression(for exercise: Exercise, now: Date = Date(), goal: TrainingGoal = .current) -> ProgressionAdvice? {
        guard !exercise.isCardio else { return nil }

        if exercise.shouldIncreaseWeight, let manual = exercise.suggestedNextWeight, manual > 0 {
            return ProgressionAdvice(kind: .manual, weight: manual, reason: "Your saved target for today.")
        }

        let history = exercise.sessions
            .filter { !$0.sets.isEmpty }
            .sorted { $0.date > $1.date }
        guard let lastSession = history.first else { return nil }

        let weights = lastSession.sets.map(\.weight).filter { $0 > 0 }
        guard let top = weights.max() else { return nil }

        let reps = lastSession.sets.map(\.reps)
        let minReps = reps.min() ?? 0
        let setCount = lastSession.sets.count
        let avgDifficulty = Double(lastSession.sets.map(\.difficulty).reduce(0, +)) / Double(lastSession.sets.count)
        let jump = weightIncrement(for: exercise)

        // Assisted lifts run backwards: the "weight" is machine help, so getting
        // stronger means *removing* it. Never advise adding load here.
        if isAssisted(exercise.name) {
            let readyToProgress = minReps >= 10 || (minReps >= 8 && avgDifficulty <= 4.0)
            if readyToProgress {
                let next = max(0, top - jump)
                if next < top {
                    return ProgressionAdvice(
                        kind: .decrease,
                        weight: next,
                        reason: "You cleared \(formatWeight(top)) lb of assist for \(minReps)+ reps — drop to \(formatWeight(next)) lb to make it harder."
                    )
                }
                return ProgressionAdvice(
                    kind: .hold,
                    weight: top,
                    reason: "You're barely using the assist — try \(exercise.name) unassisted next time."
                )
            }
            return ProgressionAdvice(
                kind: .hold,
                weight: top,
                reason: "Hold \(formatWeight(top)) lb of assist — own 8+ clean reps every set, then we take some off."
            )
        }

        // Walking back through sessions stuck at this same top weight: how
        // many in a row were grinders (avg effort ≥ 4.5), and — for strength
        // mode — how many missed the 5-rep floor.
        var grinderStreak = 0
        var grindersUnbroken = true
        var failStreak = 0
        var failsUnbroken = true
        for session in history {
            guard let sessionTop = session.sets.map(\.weight).max(), abs(sessionTop - top) < 0.01 else { break }
            let effort = Double(session.sets.map(\.difficulty).reduce(0, +)) / Double(max(session.sets.count, 1))
            if grindersUnbroken && effort >= 4.5 {
                grinderStreak += 1
            } else {
                grindersUnbroken = false
            }
            if failsUnbroken && (session.sets.map(\.reps).min() ?? 0) < strengthRepFloor {
                failStreak += 1
            } else {
                failsUnbroken = false
            }
        }

        // Three straight max-effort sessions stuck at the same weight: back
        // off ~10% and rebuild momentum instead of grinding into a wall.
        if grinderStreak >= 3 {
            let deload = max(jump, roundToIncrement(top * 0.9, increment: jump))
            if deload < top {
                return ProgressionAdvice(
                    kind: .decrease,
                    weight: deload,
                    reason: "\(grinderStreak) all-out sessions stuck at \(formatWeight(top)) lb. Deload to \(formatWeight(deload)) lb, bank easy reps, and run it back up."
                )
            }
        }

        switch goal {
        case .hypertrophy:
            // Double progression, the best-evidenced hypertrophy rule: work an
            // 8–12 rep range and add weight ONLY once every set clears the top
            // of it. Hitting 3×8 is the floor of the range, not the trigger.
            if minReps >= hypertrophyRepTop {
                return ProgressionAdvice(
                    kind: .increase,
                    weight: top + jump,
                    reason: "Every set hit \(hypertrophyRepTop) at \(formatWeight(top)) lb — go up \(formatWeight(jump)) lb and build back from 8s."
                )
            }
            if avgDifficulty >= 4.5 {
                return ProgressionAdvice(
                    kind: .hold,
                    weight: top,
                    reason: "Last session was a grinder. Own \(formatWeight(top)) lb before chasing more reps."
                )
            }
            return ProgressionAdvice(
                kind: .hold,
                weight: top,
                reason: "Add reps before weight: your lowest set was \(minReps) — get every set to \(hypertrophyRepTop) at \(formatWeight(top)) lb to earn the bump."
            )

        case .strength:
            // Linear progression (StrongLifts / Starting Strength): complete
            // every set at 5+ clean reps and the weight goes up next session.
            // Three straight sessions missing the floor triggers a 10% deload.
            if failStreak >= 3 {
                let deload = max(jump, roundToIncrement(top * 0.9, increment: jump))
                if deload < top {
                    return ProgressionAdvice(
                        kind: .decrease,
                        weight: deload,
                        reason: "\(failStreak) sessions missing \(strengthRepFloor)s at \(formatWeight(top)) lb. Deload to \(formatWeight(deload)) lb and run it back up."
                    )
                }
            }
            if minReps >= strengthRepFloor {
                return ProgressionAdvice(
                    kind: .increase,
                    weight: top + jump,
                    reason: "All \(setCount) sets at \(strengthRepFloor)+ reps with \(formatWeight(top)) lb — linear progression says add \(formatWeight(jump)) lb."
                )
            }
            return ProgressionAdvice(
                kind: .hold,
                weight: top,
                reason: "You missed \(strengthRepFloor) reps on a set at \(formatWeight(top)) lb — repeat it and finish every set next time."
            )
        }
    }

    // MARK: - e1RM & PRs

    /// Epley estimated one-rep max, rounded to a whole pound — an estimate
    /// with decimals reads as false precision everywhere it's shown.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return (weight * (1 + Double(reps) / 30.0)).rounded()
    }

    static func bestOneRepMax(in session: ExerciseSession) -> Double {
        session.sets.map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }

    /// True when this session set a new all-time e1RM for its exercise.
    static func isPersonalRecord(_ session: ExerciseSession) -> Bool {
        guard let exercise = session.exercise, !exercise.isCardio else { return false }
        let current = bestOneRepMax(in: session)
        guard current > 0 else { return false }
        let previousBest = exercise.sessions
            .filter { $0.date < session.date }
            .map(bestOneRepMax(in:))
            .max() ?? 0
        return current > previousBest
    }

    struct PersonalRecord: Identifiable {
        let id = UUID()
        let exerciseName: String
        let date: Date
        let oneRepMax: Double
        let topWeight: Double
    }

    /// PRs set within the last `days`, newest first.
    static func recentPRs(sessions: [ExerciseSession], within days: Int = 14, now: Date = Date()) -> [PersonalRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        return sessions
            .filter { $0.date >= cutoff && isPersonalRecord($0) }
            .sorted { $0.date > $1.date }
            .compactMap { session in
                guard let exercise = session.exercise else { return nil }
                return PersonalRecord(
                    exerciseName: exercise.name,
                    date: session.date,
                    oneRepMax: bestOneRepMax(in: session),
                    topWeight: session.sets.map(\.weight).max() ?? 0
                )
            }
    }

    // MARK: - Streak

    /// Consecutive training days walking back from today; untrained weekends
    /// don't break the chain (they're treated as scheduled rest), and an
    /// untrained *today* doesn't reset it either.
    static func currentStreak(sessions: [ExerciseSession], now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let trainedDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !trainedDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        if !trainedDays.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }

        while true {
            if trainedDays.contains(cursor) {
                streak += 1
            } else {
                let weekday = calendar.component(.weekday, from: cursor)
                let isWeekend = weekday == 1 || weekday == 7
                if !isWeekend { break }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            if streak == 0 && !trainedDays.contains(where: { $0 <= cursor }) { break }
        }
        return streak
    }

    // MARK: - Volume

    /// Hard sets per muscle over the trailing `days` (cardio excluded).
    static func setVolume(sessions: [ExerciseSession], days: Int, now: Date = Date()) -> [TargetMuscle: Int] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        var volume: [TargetMuscle: Int] = [:]
        for session in sessions where session.date >= cutoff {
            guard let exercise = session.exercise, !exercise.isCardio else { continue }
            for muscle in exercise.targetMuscles where muscle != .cardio {
                volume[muscle, default: 0] += session.sets.count
            }
        }
        return volume
    }

    /// Total weight moved (weight × reps summed) for a set of sessions.
    static func totalVolume(sessions: [ExerciseSession]) -> Double {
        sessions.flatMap(\.sets).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    // MARK: - Formatting helpers

    static func formatWeight(_ weight: Double) -> String {
        weight.formatted()
    }
}
