import Foundation
import SwiftData
import CryptoKit
import LocalAuthentication

/// SHA-256 helper for the progress-photos password. Not bank-grade security —
/// just keeps the photos out of casual reach when handing the phone over.
enum PasscodeHasher {
    static func hash(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Forgot-password escape hatch: proving you own the device (Face ID,
    /// Touch ID, or the device passcode) is at least as strong as the photo
    /// password, so it may reset the lock.
    static func recoverWithDeviceAuth(onSuccess: @escaping () -> Void) {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else { return }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Reset your progress photo password"
        ) { success, _ in
            if success {
                DispatchQueue.main.async(execute: onSuccess)
            }
        }
    }
}

// MARK: - TargetMuscle

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

    /// "frontDelts" → "Front Delts": split the camelCase raw value and capitalize.
    var displayName: String {
        rawValue.reduce(into: "") { $0 += $1.isUppercase ? " \($1)" : String($1) }.capitalized
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

extension Double {
    /// Parses user keyboard input, accepting both "." and "," decimal
    /// separators — decimal pads produce "," in many locales and
    /// `Double.init(_:)` silently rejects it.
    init?(userInput: String) {
        self.init(userInput.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: "."))
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
    case gym = "The Gym"

    var id: String { rawValue }

    /// Decodes stored values, mapping the pre-rename "Planet Fitness" rows.
    static func from(stored: String) -> WorkoutLocation {
        WorkoutLocation(rawValue: stored) ?? .gym
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .gym: return "building.2.fill"
        }
    }
}

/// One calendar day's creatine check-in. (The workout itself lives in
/// ExerciseSession rows — this model exists only for the daily creatine flag.)
@Model
class WorkoutDay {
    var date: Date
    var tookCreatine: Bool

    init(date: Date, tookCreatine: Bool = false) {
        self.date = Calendar.current.startOfDay(for: date)
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
    /// Home and gym keep fully separate exercise libraries; pre-existing
    /// exercises default to the gym, where their history was logged.
    var locationRawValue: String = WorkoutLocation.gym.rawValue

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSession.exercise)
    var sessions: [ExerciseSession] = []

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .rest }
        set { typeRawValue = newValue.rawValue }
    }

    var location: WorkoutLocation {
        get { WorkoutLocation.from(stored: locationRawValue) }
        set { locationRawValue = newValue.rawValue }
    }

    var targetMuscles: Set<TargetMuscle> {
        get {
            // "none" marks an explicit empty selection; a truly empty array is
            // a legacy row that predates muscle targets and gets the defaults.
            if targetMuscleRawValues == ["none"] { return [] }
            let savedTargets = Set(targetMuscleRawValues.compactMap(TargetMuscle.init(rawValue:)))
            if savedTargets.isEmpty {
                return MuscleCatalog.defaultTargets(for: name, type: type, isCardio: isCardio)
            }

            return savedTargets
        }
        set {
            targetMuscleRawValues = newValue.isEmpty ? ["none"] : newValue.map(\.rawValue).sorted()
        }
    }
    
    init(name: String, type: WorkoutType, isCardio: Bool = false, location: WorkoutLocation = .gym) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.isCardio = isCardio
        self.suggestedNextWeight = nil
        self.shouldIncreaseWeight = false
        self.targetMuscleRawValues = MuscleCatalog.defaultTargets(for: name, type: type, isCardio: isCardio).map(\.rawValue).sorted()
        self.locationRawValue = location.rawValue
    }
}

extension Exercise {
    /// Whether this exercise already has a session logged today.
    var isCompletedToday: Bool {
        sessions.contains { Calendar.current.isDateInToday($0.date) }
    }
}

@Model
class ExerciseSession {
    var date: Date
    var machineSettings: String
    var totalSets: Int
    var notes: String
    var locationRawValue: String = WorkoutLocation.gym.rawValue
    
    // Cardio Specific Metrics
    var warmUpTime: Double?
    var runningTime: Double?
    var coolDownTime: Double?
    var runningSpeed: Double?
    var intensityRating: Int?
    
    var exercise: Exercise?

    var location: WorkoutLocation {
        get { WorkoutLocation.from(stored: locationRawValue) }
        set { locationRawValue = newValue.rawValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet] = []
    
    init(date: Date, machineSettings: String, totalSets: Int, notes: String = "", location: WorkoutLocation = .gym, warmUpTime: Double? = nil, runningTime: Double? = nil, coolDownTime: Double? = nil, runningSpeed: Double? = nil, intensityRating: Int? = nil) {
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

/// The pose a progress photo captures, so timelines can be compared like-for-like.
enum ProgressPose: String, CaseIterable, Identifiable, Codable {
    case front = "Front"
    case side = "Side"
    case back = "Back"
    case legs = "Legs"

    var id: String { rawValue }

    static func from(stored: String) -> ProgressPose {
        ProgressPose(rawValue: stored) ?? .front
    }
}

@Model
class ProgressPhoto {
    var date: Date
    var imageData: Data
    var notes: String
    /// Which pose this shot is. Defaults to Front so pre-existing rows migrate cleanly.
    var poseRawValue: String = ProgressPose.front.rawValue

    var pose: ProgressPose {
        get { ProgressPose.from(stored: poseRawValue) }
        set { poseRawValue = newValue.rawValue }
    }

    init(date: Date, imageData: Data, notes: String = "", pose: ProgressPose = .front) {
        self.date = date
        self.imageData = imageData
        self.notes = notes
        self.poseRawValue = pose.rawValue
    }
}
