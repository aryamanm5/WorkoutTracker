import Foundation
import SwiftData
import SwiftUI

@Observable
class WorkoutViewModel {
    
    // Automatic Workout Schedule
    func getTodayWorkoutType() -> WorkoutType {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 2, 5: return .push // Monday, Thursday
        case 3, 6: return .pull // Tuesday, Friday
        case 4, 7: return .legs // Wednesday, Saturday
        default: return .rest   // Sunday
        }
    }
    
    func isExerciseCompletedToday(_ exercise: Exercise) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return exercise.sessions.contains { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    
    func getPreviousSession(for exercise: Exercise) -> ExerciseSession? {
        return exercise.sessions.sorted { $0.date > $1.date }.first
    }
    
    // Automatically marks skipped days as Rest Days
    func processMissingDays(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let today = Calendar.current.startOfDay(for: Date())
        
        do {
            let pastDays = try context.fetch(descriptor)
            guard let lastLoggedDay = pastDays.first?.date else {
                // First time opening app, log today
                let newDay = WorkoutDay(date: today, type: getTodayWorkoutType())
                context.insert(newDay)
                return
            }
            
            var currentDate = Calendar.current.date(byAdding: .day, value: 1, to: lastLoggedDay)!
            
            while currentDate < today {
                let restDay = WorkoutDay(date: currentDate, type: .rest)
                context.insert(restDay)
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            if !pastDays.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                let todayRecord = WorkoutDay(date: today, type: getTodayWorkoutType())
                context.insert(todayRecord)
            }
            
            try context.save()
        } catch {
            print("Failed to process missing days: \(error)")
        }
    }
}
