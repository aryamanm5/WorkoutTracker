import Foundation
import SwiftData

enum WorkoutType: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case rest = "Rest"
}

@Model
class WorkoutDay {
    var date: Date
    var typeRawValue: String
    
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .rest }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(date: Date, type: WorkoutType) {
        self.date = Calendar.current.startOfDay(for: date)
        self.typeRawValue = type.rawValue
    }
}

@Model
class Exercise {
    var name: String
    var typeRawValue: String
    var isCardio: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.exercise)
    var sessions: [ExerciseSession] = []
    
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .rest }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(name: String, type: WorkoutType, isCardio: Bool = false) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.isCardio = isCardio
    }
}

@Model
class ExerciseSession {
    var date: Date
    var machineSettings: String
    var totalSets: Int
    var notes: String
    
    // Cardio Specific Metrics
    var warmUpTime: Double?
    var runningTime: Double?
    var coolDownTime: Double?
    var runningSpeed: Double?
    var intensityRating: Int?
    
    var exercise: Exercise?
    
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet] = []
    
    init(date: Date, machineSettings: String, totalSets: Int, notes: String = "", warmUpTime: Double? = nil, runningTime: Double? = nil, coolDownTime: Double? = nil, runningSpeed: Double? = nil, intensityRating: Int? = nil) {
        self.date = date
        self.machineSettings = machineSettings
        self.totalSets = totalSets
        self.notes = notes
        
        self.warmUpTime = warmUpTime
        self.runningTime = runningTime
        self.coolDownTime = coolDownTime
        self.runningSpeed = runningSpeed
        self.intensityRating = intensityRating
    }
}

@Model
class LoggedSet {
    var setNumber: Int
    var reps: Int
    var weight: Double
    var session: ExerciseSession?
    
    init(setNumber: Int, reps: Int, weight: Double) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
    }
}
