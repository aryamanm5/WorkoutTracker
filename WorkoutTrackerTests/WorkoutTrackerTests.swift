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
}
