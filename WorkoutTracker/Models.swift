import Foundation
import SwiftData

// MARK: - TargetMuscle
// Paste this block at the top of Models.swift, before WorkoutType

enum TargetMuscle: String, CaseIterable, Identifiable, Codable, Hashable {
    case chest
    case lats
    case upperBack
    case frontDelts
    case sideDelts
    case rearDelts
    case biceps
    case triceps
    case forearms
    case abs
    case quads
    case hamstrings
    case glutes
    case calves
    case cardio
    case traps
    case obliques
    case lowerBack
    case serratus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest:      return "Chest"
        case .lats:       return "Lats"
        case .upperBack:  return "Upper Back"
        case .frontDelts: return "Front Delts"
        case .sideDelts:  return "Side Delts"
        case .rearDelts:  return "Rear Delts"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .abs:        return "Abs"
        case .quads:      return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes:     return "Glutes"
        case .calves:     return "Calves"
        case .cardio:     return "Cardio"
        case .traps:      return "Traps"
        case .obliques:   return "Obliques"
        case .lowerBack:  return "Lower Back"
        case .serratus:   return "Serratus"
        }
    }
}

// MARK: - MuscleCatalog

struct MuscleCatalog {
    static func defaultTargets(for exerciseName: String,
                                type: WorkoutType,
                                isCardio: Bool) -> Set<TargetMuscle> {
        guard !isCardio else { return [.cardio, .quads, .hamstrings, .calves] }

        let name = exerciseName.lowercased()
        var muscles = Set<TargetMuscle>()

        // Specific phrases are matched before generic keywords so that
        // e.g. "Rear Delt Fly" targets rear delts, not chest.
        if name.contains("rear delt") || name.contains("reverse fly") || name.contains("face pull") {
            muscles.formUnion([.rearDelts, .upperBack])
        } else if name.contains("lateral") || name.contains("side raise") {
            muscles.insert(.sideDelts)
        } else if name.contains("front raise") {
            muscles.insert(.frontDelts)
        } else if name.contains("shoulder press") || name.contains("overhead press") || name.contains("military") {
            muscles.formUnion([.frontDelts, .sideDelts, .triceps])
        }

        if name.contains("leg curl") || name.contains("hamstring") || name.contains("rdl")
            || name.contains("romanian") || name.contains("good morning") {
            muscles.formUnion([.hamstrings, .glutes])
        } else if name.contains("leg extension") {
            muscles.insert(.quads)
        } else if name.contains("leg press") || name.contains("squat") || name.contains("lunge")
            || name.contains("hack") {
            muscles.formUnion([.quads, .glutes])
        } else if name.contains("curl") {
            muscles.formUnion([.biceps, .forearms])
        }

        if name.contains("bench") || name.contains("chest") || name.contains("push up")
            || name.contains("pushup") || (name.contains("fly") && !name.contains("rear") && !name.contains("reverse")) {
            muscles.formUnion([.chest, .frontDelts, .triceps])
        }
        if name.contains("tricep") || name.contains("dip") || name.contains("pushdown")
            || name.contains("skull") {
            muscles.insert(.triceps)
        }
        if name.contains("pull up") || name.contains("pullup") || name.contains("pull-up")
            || name.contains("pulldown") || name.contains("pull down") || name.contains("chin") {
            muscles.formUnion([.lats, .upperBack, .biceps])
        }
        if name.contains("row") {
            muscles.formUnion([.lats, .upperBack, .rearDelts, .biceps])
        }
        if name.contains("deadlift") {
            muscles.formUnion([.hamstrings, .glutes, .lowerBack, .traps, .forearms])
        }
        if name.contains("shrug") {
            muscles.insert(.traps)
        }
        if name.contains("calf") || name.contains("calves") {
            muscles.insert(.calves)
        }
        if name.contains("adductor") {
            muscles.insert(.hamstrings)
        } else if name.contains("abductor") || name.contains("hip") || name.contains("glute") {
            muscles.insert(.glutes)
        }
        if name.contains("crunch") || name.contains("plank") || name.contains("sit up")
            || name.contains("situp") || name.contains("ab ") || name.hasSuffix(" ab")
            || name.contains("leg raise") {
            muscles.insert(.abs)
        }
        if name.contains("oblique") || name.contains("twist") || name.contains("side bend") {
            muscles.insert(.obliques)
        }
        if name.contains("forearm") || name.contains("wrist") || name.contains("grip") {
            muscles.insert(.forearms)
        }
        if name.contains("back extension") || name.contains("lower back") || name.contains("hyperextension") {
            muscles.insert(.lowerBack)
        }

        if muscles.isEmpty {
            muscles.formUnion(defaultTargets(for: type))
        }

        return muscles
    }

    static func defaultTargets(for type: WorkoutType) -> Set<TargetMuscle> {
        switch type {
        case .push: return [.chest, .frontDelts, .sideDelts, .triceps]
        case .pull: return [.lats, .upperBack, .rearDelts, .biceps, .forearms]
        case .legs: return [.quads, .hamstrings, .glutes, .calves]
        case .rest: return []
        }
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Legs"
    case rest = "Rest"
}

enum WorkoutLocation: String, Codable, CaseIterable, Identifiable {
    case home = "Home"
    case planetFitness = "Planet Fitness"

    var id: String { rawValue }
}

@Model
class WorkoutDay {
    var date: Date
    var typeRawValue: String
    var tookCreatine: Bool
    
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .rest }
        set { typeRawValue = newValue.rawValue }
    }
    
    init(date: Date, type: WorkoutType, tookCreatine: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
        self.typeRawValue = type.rawValue
        self.tookCreatine = tookCreatine
    }
}

@Model
class Exercise {
    var name: String
    var typeRawValue: String
    var isCardio: Bool
    var suggestedNextWeight: Double?
    var shouldIncreaseWeight: Bool
    var targetMuscleRawValues: [String] = []
    
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.exercise)
    var sessions: [ExerciseSession] = []
    
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .rest }
        set { typeRawValue = newValue.rawValue }
    }

    var targetMuscles: Set<TargetMuscle> {
        get {
            let savedTargets = Set(targetMuscleRawValues.compactMap(TargetMuscle.init(rawValue:)))
            if savedTargets.isEmpty {
                return MuscleCatalog.defaultTargets(for: name, type: type, isCardio: isCardio)
            }

            return savedTargets
        }
        set {
            targetMuscleRawValues = newValue.map(\.rawValue).sorted()
        }
    }
    
    init(name: String, type: WorkoutType, isCardio: Bool = false) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.isCardio = isCardio
        self.suggestedNextWeight = nil
        self.shouldIncreaseWeight = false
        self.targetMuscleRawValues = MuscleCatalog.defaultTargets(for: name, type: type, isCardio: isCardio).map(\.rawValue).sorted()
    }
}

@Model
class ExerciseSession {
    var date: Date
    var machineSettings: String
    var totalSets: Int
    var notes: String
    var locationRawValue: String = WorkoutLocation.planetFitness.rawValue
    
    // Cardio Specific Metrics
    var warmUpTime: Double?
    var runningTime: Double?
    var coolDownTime: Double?
    var runningSpeed: Double?
    var intensityRating: Int?
    
    var exercise: Exercise?

    var location: WorkoutLocation {
        get { WorkoutLocation(rawValue: locationRawValue) ?? .planetFitness }
        set { locationRawValue = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet] = []
    
    init(date: Date, machineSettings: String, totalSets: Int, notes: String = "", location: WorkoutLocation = .planetFitness, warmUpTime: Double? = nil, runningTime: Double? = nil, coolDownTime: Double? = nil, runningSpeed: Double? = nil, intensityRating: Int? = nil) {
        self.date = date
        self.machineSettings = machineSettings
        self.totalSets = totalSets
        self.notes = notes
        self.locationRawValue = location.rawValue
        
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
    var notes: String
    var difficulty: Int // 1-5 rating
    var restTimeSeconds: Int?
    var session: ExerciseSession?
    
    init(setNumber: Int, reps: Int, weight: Double, notes: String = "", difficulty: Int = 3, restTimeSeconds: Int? = nil) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.notes = notes
        self.difficulty = difficulty
        self.restTimeSeconds = restTimeSeconds
    }
}

@Model
class BodyWeightEntry {
    var date: Date
    var weight: Double
    var notes: String
    
    init(date: Date, weight: Double, notes: String = "") {
        self.date = date
        self.weight = weight
        self.notes = notes
    }
}

@Model
class ProgressPhoto {
    var date: Date
    var imageData: Data
    var notes: String

    init(date: Date, imageData: Data, notes: String = "") {
        self.date = date
        self.imageData = imageData
        self.notes = notes
    }
}
