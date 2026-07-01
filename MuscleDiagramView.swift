import SwiftUI


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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .lats: return "Lats"
        case .upperBack: return "Upper Back"
        case .frontDelts: return "Front Delts"
        case .sideDelts: return "Side Delts"
        case .rearDelts: return "Rear Delts"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .abs: return "Abs"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .cardio: return "Cardio"
        }
    }
}

struct MuscleCatalog {
    static func defaultTargets(for exerciseName: String, type: WorkoutType, isCardio: Bool) -> Set<TargetMuscle> {
        guard !isCardio else { return [.cardio, .calves, .abs] }

        let name = exerciseName.lowercased()
        var muscles = Set<TargetMuscle>()

        if name.contains("bench") || name.contains("chest") || name.contains("fly") {
            muscles.formUnion([.chest, .frontDelts])
        }
        if name.contains("shoulder") || name.contains("overhead") {
            muscles.formUnion([.frontDelts, .sideDelts, .triceps])
        }
        if name.contains("lateral") {
            muscles.insert(.sideDelts)
        }
        if name.contains("rear delt") {
            muscles.insert(.rearDelts)
        }
        if name.contains("tricep") || name.contains("dip") {
            muscles.insert(.triceps)
        }
        if name.contains("pull") || name.contains("row") {
            muscles.formUnion([.lats, .upperBack, .biceps])
        }
        if name.contains("curl") {
            muscles.formUnion([.biceps, .forearms])
        }
        if name.contains("leg press") || name.contains("extension") {
            muscles.formUnion([.quads, .glutes])
        }
        if name.contains("leg curl") || name.contains("hamstring") {
            muscles.insert(.hamstrings)
        }
        if name.contains("calf") {
            muscles.insert(.calves)
        }
        if name.contains("hip") || name.contains("glute") {
            muscles.insert(.glutes)
        }

        if muscles.isEmpty {
            muscles.formUnion(defaultTargets(for: type))
        }

        return muscles
    }

    static func defaultTargets(for type: WorkoutType) -> Set<TargetMuscle> {
        switch type {
        case .push:
            return [.chest, .frontDelts, .sideDelts, .triceps]
        case .pull:
            return [.lats, .upperBack, .rearDelts, .biceps, .forearms]
        case .legs:
            return [.quads, .hamstrings, .glutes, .calves]
        case .rest:
            return []
        }
    }
}

struct MuscleDiagramView: View {
    let activatedMuscles: Set<TargetMuscle>
    let restingMuscles: Set<TargetMuscle>
    var selectedMuscles: Binding<Set<TargetMuscle>>?
    var isEditable: Bool = false

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    bodyBase(size: size)

                    ForEach(TargetMuscle.allCases) { muscle in
                        MuscleButton(
                            muscle: muscle,
                            state: state(for: muscle),
                            frame: frame(for: muscle, in: size),
                            isEditable: isEditable,
                            action: { toggle(muscle) }
                        )
                    }
                }
            }
            .frame(height: 360)

            HStack(spacing: 16) {
                legend(color: .red, label: isEditable ? "Selected" : "Worked Today")
                legend(color: .orange, label: isEditable ? "Available" : "Resting")
            }
        }
    }

    private func bodyBase(size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(themeManager.secondaryBackground)
                .overlay(Circle().stroke(themeManager.cardBorder, lineWidth: 1))
                .frame(width: size.width * 0.18, height: size.width * 0.18)
                .position(x: size.width * 0.5, y: size.height * 0.08)

            RoundedRectangle(cornerRadius: 36)
                .fill(themeManager.secondaryBackground.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 36).stroke(themeManager.cardBorder, lineWidth: 1))
                .frame(width: size.width * 0.34, height: size.height * 0.36)
                .position(x: size.width * 0.5, y: size.height * 0.34)

            RoundedRectangle(cornerRadius: 22)
                .fill(themeManager.secondaryBackground.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(themeManager.cardBorder, lineWidth: 1))
                .frame(width: size.width * 0.46, height: size.height * 0.16)
                .position(x: size.width * 0.5, y: size.height * 0.58)

            Capsule()
                .fill(themeManager.secondaryBackground.opacity(0.7))
                .overlay(Capsule().stroke(themeManager.cardBorder, lineWidth: 1))
                .frame(width: size.width * 0.16, height: size.height * 0.34)
                .position(x: size.width * 0.39, y: size.height * 0.79)

            Capsule()
                .fill(themeManager.secondaryBackground.opacity(0.7))
                .overlay(Capsule().stroke(themeManager.cardBorder, lineWidth: 1))
                .frame(width: size.width * 0.16, height: size.height * 0.34)
                .position(x: size.width * 0.61, y: size.height * 0.79)
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundColor(themeManager.secondaryText)
        }
    }

    private func state(for muscle: TargetMuscle) -> MuscleDisplayState {
        if let selectedMuscles, selectedMuscles.wrappedValue.contains(muscle) {
            return .active
        }
        if activatedMuscles.contains(muscle) {
            return .active
        }
        if restingMuscles.contains(muscle) || isEditable {
            return .resting
        }
        return .inactive
    }

    private func toggle(_ muscle: TargetMuscle) {
        guard isEditable, let selectedMuscles else { return }
        if selectedMuscles.wrappedValue.contains(muscle) {
            selectedMuscles.wrappedValue.remove(muscle)
        } else {
            selectedMuscles.wrappedValue.insert(muscle)
        }
    }

    private func frame(for muscle: TargetMuscle, in size: CGSize) -> CGRect {
        let w = size.width
        let h = size.height
        switch muscle {
        case .chest: return CGRect(x: w * 0.38, y: h * 0.20, width: w * 0.24, height: h * 0.11)
        case .lats: return CGRect(x: w * 0.29, y: h * 0.28, width: w * 0.13, height: h * 0.20)
        case .upperBack: return CGRect(x: w * 0.43, y: h * 0.38, width: w * 0.14, height: h * 0.10)
        case .frontDelts: return CGRect(x: w * 0.33, y: h * 0.18, width: w * 0.12, height: h * 0.09)
        case .sideDelts: return CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.12, height: h * 0.09)
        case .rearDelts: return CGRect(x: w * 0.55, y: h * 0.31, width: w * 0.12, height: h * 0.09)
        case .biceps: return CGRect(x: w * 0.22, y: h * 0.30, width: w * 0.12, height: h * 0.15)
        case .triceps: return CGRect(x: w * 0.66, y: h * 0.30, width: w * 0.12, height: h * 0.15)
        case .forearms: return CGRect(x: w * 0.19, y: h * 0.47, width: w * 0.13, height: h * 0.13)
        case .abs: return CGRect(x: w * 0.42, y: h * 0.33, width: w * 0.16, height: h * 0.17)
        case .quads: return CGRect(x: w * 0.35, y: h * 0.62, width: w * 0.13, height: h * 0.19)
        case .hamstrings: return CGRect(x: w * 0.52, y: h * 0.62, width: w * 0.13, height: h * 0.19)
        case .glutes: return CGRect(x: w * 0.42, y: h * 0.52, width: w * 0.16, height: h * 0.10)
        case .calves: return CGRect(x: w * 0.42, y: h * 0.82, width: w * 0.16, height: h * 0.14)
        case .cardio: return CGRect(x: w * 0.72, y: h * 0.04, width: w * 0.18, height: h * 0.08)
        }
    }
}

private enum MuscleDisplayState {
    case active
    case resting
    case inactive

    var fill: Color {
        switch self {
        case .active: return .red
        case .resting: return .orange
        case .inactive: return .gray.opacity(0.25)
        }
    }

    var textColor: Color {
        switch self {
        case .active, .resting: return .white
        case .inactive: return .secondary
        }
    }
}

private struct MuscleButton: View {
    let muscle: TargetMuscle
    let state: MuscleDisplayState
    let frame: CGRect
    let isEditable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(muscle.displayName)
                .font(.system(size: 9, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.65)
                .foregroundColor(state.textColor)
                .frame(width: frame.width, height: frame.height)
                .background(state.fill)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(state == .inactive ? 0.2 : 0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
        .position(x: frame.midX, y: frame.midY)
    }
}
