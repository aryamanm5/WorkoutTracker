//
//  WorkoutTrackerTests.swift
//  WorkoutTrackerTests
//
//  Created by Aryaman Mishra on 6/17/26.
//

import Testing
import Foundation
import SwiftData
@testable import WorkoutTracker

@MainActor
struct TrainingEngineTests {

    /// Builds an exercise with one recent session of the given sets inside an
    /// in-memory container. The container is returned so the models stay alive.
    private func makeExercise(
        name: String,
        sets: [(reps: Int, weight: Double)],
        difficulty: Int = 3
    ) throws -> (ModelContainer, Exercise) {
        let container = try ModelContainer(
            for: Exercise.self, ExerciseSession.self, LoggedSet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let exercise = Exercise(name: name, type: .push)
        context.insert(exercise)

        let session = ExerciseSession(
            date: Date().addingTimeInterval(-2 * 86400),
            machineSettings: "",
            totalSets: sets.count
        )
        context.insert(session)
        session.exercise = exercise

        for (index, spec) in sets.enumerated() {
            let set = LoggedSet(setNumber: index + 1, reps: spec.reps, weight: spec.weight, difficulty: difficulty)
            context.insert(set)
            set.session = session
        }
        return (container, exercise)
    }

    @Test func hypertrophyHoldsAtBottomOfRepRange() throws {
        // 3×8 is the FLOOR of the 8–12 range — the coach must not call for
        // more weight until every set clears 12.
        let (container, exercise) = try makeExercise(name: "Bench Press", sets: Array(repeating: (8, 135.0), count: 3))
        let advice = try #require(TrainingEngine.progression(for: exercise, goal: .hypertrophy))
        #expect(advice.kind == .hold)
        _ = container
    }

    @Test func hypertrophyIncreasesAtTopOfRepRange() throws {
        let (container, exercise) = try makeExercise(name: "Bench Press", sets: Array(repeating: (12, 135.0), count: 3))
        let advice = try #require(TrainingEngine.progression(for: exercise, goal: .hypertrophy))
        #expect(advice.kind == .increase)
        #expect(advice.weight == 140)
        _ = container
    }

    @Test func strengthIncreasesEveryCompletedSession() throws {
        let (container, exercise) = try makeExercise(name: "Bench Press", sets: Array(repeating: (5, 185.0), count: 3))
        let advice = try #require(TrainingEngine.progression(for: exercise, goal: .strength))
        #expect(advice.kind == .increase)
        #expect(advice.weight == 190)
        _ = container
    }

    @Test func strengthRepeatsAfterMissedReps() throws {
        let (container, exercise) = try makeExercise(name: "Bench Press", sets: [(5, 185.0), (5, 185.0), (3, 185.0)])
        let advice = try #require(TrainingEngine.progression(for: exercise, goal: .strength))
        #expect(advice.kind == .hold)
        #expect(advice.weight == 185)
        _ = container
    }

    @Test func incrementsMatchEquipment() throws {
        func increment(_ name: String) throws -> Double {
            let (container, exercise) = try makeExercise(name: name, sets: [(8, 100.0)])
            defer { _ = container }
            return TrainingEngine.weightIncrement(for: exercise)
        }
        #expect(try increment("Bicep Curl") == 2.5)
        #expect(try increment("Deadlift") == 10)
        #expect(try increment("Chest Press Machine") == 10)
        #expect(try increment("Bench Press") == 5)
    }

    @Test func oneRepMaxIsRounded() {
        // Epley: 100 × (1 + 8/30) = 126.67 → 127
        #expect(TrainingEngine.estimatedOneRepMax(weight: 100, reps: 8) == 127)
    }

    // MARK: - Coach's pick

    /// Noon on a fixed date whose weekday is known (July 13, 2026 is a Monday).
    private func noon(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func coachFollowsWeeklySplitWhenFresh() {
        // With no fatigue, the pick tracks the fixed schedule:
        // Push Mon/Thu, Pull Tue/Fri, Legs Wed/Sat, rest Sunday.
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 13)).type == .push)  // Mon
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 14)).type == .pull)  // Tue
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 15)).type == .legs)  // Wed
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 16)).type == .push)  // Thu
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 17)).type == .pull)  // Fri
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 18)).type == .legs)  // Sat
        #expect(TrainingEngine.recommendation(sessions: [], now: noon(2026, 7, 19)).type == .rest)  // Sun
    }

    // MARK: - CSV round-trip

    private func makeFullContainer() throws -> ModelContainer {
        try ModelContainer(
            for: WorkoutDay.self, Exercise.self, ExerciseSession.self, LoggedSet.self,
            BodyWeightEntry.self, BodyMeasurement.self, ProgressPhoto.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test func csvRoundTripsWorkoutsWeightsAndMeasurements() throws {
        let source = try makeFullContainer()
        let context = source.mainContext

        let exercise = Exercise(name: "Bench Press", type: .push)
        context.insert(exercise)
        let session = ExerciseSession(date: Date().addingTimeInterval(-86400),
                                      machineSettings: "Seat 3", totalSets: 2, notes: "solid, felt good")
        context.insert(session)
        session.exercise = exercise
        for n in 1...2 {
            let set = LoggedSet(setNumber: n, reps: 8, weight: 135, difficulty: 4)
            context.insert(set)
            set.session = session
        }
        context.insert(BodyWeightEntry(date: Date().addingTimeInterval(-3600), weight: 178.4))
        context.insert(BodyMeasurement(date: Date().addingTimeInterval(-7200), site: .waist,
                                       value: 34.25, notes: "morning, relaxed"))
        context.insert(BodyMeasurement(date: Date().addingTimeInterval(-604800), site: .leftArm, value: 14.5))
        try context.save()

        let csv = WorkoutCSV(context: context).exportString()

        let destination = try makeFullContainer()
        let summary = WorkoutCSV(context: destination.mainContext).importString(csv)
        try destination.mainContext.save()

        #expect(summary.sessions == 1)
        #expect(summary.sets == 2)
        #expect(summary.weights == 1)
        #expect(summary.measurements == 2)
        #expect(summary.skipped == 0)

        let imported = try destination.mainContext.fetch(FetchDescriptor<BodyMeasurement>())
        let waist = try #require(imported.first { $0.site == .waist })
        #expect(waist.value == 34.25)
        #expect(waist.notes == "morning, relaxed")
    }

    @Test func csvReimportSkipsEverythingAsDuplicate() throws {
        let container = try makeFullContainer()
        let context = container.mainContext

        context.insert(BodyWeightEntry(date: Date(), weight: 180))
        context.insert(BodyMeasurement(date: Date(), site: .chest, value: 41))
        let exercise = Exercise(name: "Squat", type: .legs)
        context.insert(exercise)
        let session = ExerciseSession(date: Date(), machineSettings: "", totalSets: 1)
        context.insert(session)
        session.exercise = exercise
        let set = LoggedSet(setNumber: 1, reps: 5, weight: 225)
        context.insert(set)
        set.session = session
        try context.save()

        // Importing our own export back into the same store must change nothing.
        let csv = WorkoutCSV(context: context).exportString()
        let summary = WorkoutCSV(context: context).importString(csv)

        #expect(summary.sessions == 0)
        #expect(summary.sets == 0)
        #expect(summary.weights == 0)
        #expect(summary.measurements == 0)
        #expect(summary.skipped == 3)
    }

    @Test func coachSwapsAwayFromFatiguedMuscles() throws {
        // A hard push session 12h before a scheduled push day: those muscles
        // are still beat up, so the coach should point somewhere fresher.
        let now = noon(2026, 7, 13) // Monday → scheduled push
        let (container, exercise) = try makeExercise(
            name: "Bench Press",
            sets: Array(repeating: (10, 135.0), count: 3),
            difficulty: 5
        )
        let session = try #require(exercise.sessions.first)
        session.date = now.addingTimeInterval(-12 * 3600)

        let pick = TrainingEngine.recommendation(sessions: [session], now: now)
        #expect(pick.type != .push)
        #expect(pick.type != .rest)
        _ = container
    }
}
