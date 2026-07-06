import SwiftUI

private enum MuscleDisplayState {
    case active
    case resting

    var color: Color {
        switch self {
        case .active:
            Color(red: 0.85, green: 0.15, blue: 0.15)
        case .resting:
            Color(red: 0.90, green: 0.50, blue: 0.10)
        }
    }
}

private extension TargetMuscle {
    /// Which drawable body-map regions represent this muscle on a given side.
    /// The path data only has whole-deltoid shapes plus a front-deltoid
    /// sub-shape, so delts are mapped per side to stay anatomically honest.
    func mapMuscles(on side: BodySide) -> Set<Muscle> {
        switch self {
        case .chest:
            return side == .front ? [.chest] : []
        case .lats, .upperBack:
            return side == .back ? [.upperBack] : []
        case .frontDelts:
            return side == .front ? [.frontDeltoid] : []
        case .sideDelts:
            return [.deltoids]
        case .rearDelts:
            return side == .back ? [.deltoids] : []
        case .biceps:
            return [.biceps]
        case .triceps:
            return [.triceps]
        case .forearms:
            return [.forearm]
        case .abs:
            return side == .front ? [.abs] : []
        case .quads:
            return side == .front ? [.quadriceps] : []
        case .hamstrings:
            return side == .back ? [.hamstring] : []
        case .glutes:
            return side == .back ? [.gluteal] : []
        case .calves:
            return [.calves, .tibialis]
        case .cardio:
            return []
        case .traps:
            return [.trapezius]
        case .obliques:
            return side == .front ? [.obliques] : []
        case .lowerBack:
            return side == .back ? [.lowerBack] : []
        case .serratus:
            return side == .front ? [.serratus] : []
        }
    }
}

extension Muscle {
    /// Reverse lookup used when tapping the diagram in edit mode.
    func targetMuscle(on side: BodySide) -> TargetMuscle? {
        switch parentGroup ?? self {
        case .chest:
            return .chest
        case .upperBack, .rhomboids:
            return .upperBack
        case .deltoids:
            return side == .back ? .rearDelts : .sideDelts
        case .biceps:
            return .biceps
        case .triceps:
            return .triceps
        case .forearm:
            return .forearms
        case .abs:
            return .abs
        case .quadriceps:
            return .quads
        case .hamstring:
            return .hamstrings
        case .gluteal:
            return .glutes
        case .calves, .tibialis:
            return .calves
        case .trapezius:
            return .traps
        case .obliques:
            return .obliques
        case .lowerBack:
            return .lowerBack
        default:
            return nil
        }
    }

    fileprivate func editorTarget(on side: BodySide) -> TargetMuscle? {
        // In edit mode the front-deltoid sub-shape maps to front delts directly.
        if self == .frontDeltoid { return .frontDelts }
        if self == .serratus { return .serratus }
        return targetMuscle(on: side)
    }
}

private struct MuscleMapPanel: View {
    let side: BodySide
    let activatedMuscles: Set<TargetMuscle>
    let restingMuscles: Set<TargetMuscle>
    var selectedMuscles: Binding<Set<TargetMuscle>>?
    let isEditable: Bool

    @EnvironmentObject var themeManager: ThemeManager

    private var style: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: defaultFill,
            strokeColor: themeManager.cardBorder.opacity(0.75),
            strokeWidth: 0.55,
            selectionColor: MuscleDisplayState.active.color,
            selectionStrokeColor: Color(red: 1.0, green: 0.35, blue: 0.35),
            selectionStrokeWidth: 1.6,
            headColor: Color(
                light: Color(red: 0.78, green: 0.83, blue: 0.90),
                dark: Color(red: 0.14, green: 0.24, blue: 0.36)
            ),
            hairColor: Color(
                light: Color(red: 0.28, green: 0.32, blue: 0.38),
                dark: Color(red: 0.05, green: 0.08, blue: 0.11)
            ),
            shadowColor: .clear,
            shadowRadius: 0,
            shadowOffset: .zero
        )
    }

    private var defaultFill: Color {
        Color(
            light: Color(red: 0.80, green: 0.85, blue: 0.92),
            dark: Color(red: 0.12, green: 0.22, blue: 0.34)
        )
    }

    private func mapped(_ targets: Set<TargetMuscle>) -> Set<Muscle> {
        Set(targets.flatMap { $0.mapMuscles(on: side) })
    }

    var body: some View {
        configuredBodyView
            .aspectRatio(CGSize(width: 250, height: 520), contentMode: .fit)
    }

    private var configuredBodyView: BodyView {
        var bodyView = BodyView(gender: .male, side: side, style: style)
            .showSubGroups()

        if isEditable, let selectedMuscles {
            let selected = mapped(selectedMuscles.wrappedValue)
            bodyView = bodyView.selected(selected)
            bodyView = applySubGroupMasks(to: bodyView, highlighted: selected, active: selected)
        } else {
            let active = mapped(activatedMuscles)
            let resting = mapped(restingMuscles).subtracting(active)

            for muscle in resting {
                bodyView = bodyView.highlight(muscle, color: MuscleDisplayState.resting.color, opacity: 0.82)
            }
            for muscle in active {
                bodyView = bodyView.highlight(muscle, color: MuscleDisplayState.active.color, opacity: 0.92)
            }
            bodyView = applySubGroupMasks(to: bodyView, highlighted: active.union(resting), active: active.union(resting))
        }

        if isEditable {
            bodyView = bodyView
                .onMuscleSelected { muscle, _ in
                    toggle(muscle)
                }
                .tooltip { muscle, _ in
                    tooltipLabel(for: muscle)
                }
                .pulseSelected(speed: 1.2, range: 0.72...1.0)
        } else {
            bodyView = bodyView
                .tooltip { muscle, _ in
                    tooltipLabel(for: muscle)
                }
                .animated(duration: 0.25)
        }

        return bodyView
    }

    /// The renderer lets sub-group shapes inherit their parent's highlight.
    /// When the whole deltoid is lit but front delts weren't worked (or the
    /// obliques are lit but not the serratus), repaint the sub-shape with the
    /// default fill so it doesn't read as worked.
    private func applySubGroupMasks(to bodyView: BodyView, highlighted: Set<Muscle>, active: Set<Muscle>) -> BodyView {
        var result = bodyView
        if side == .front {
            if highlighted.contains(.deltoids) && !active.contains(.frontDeltoid) {
                result = result.highlight(.frontDeltoid, color: defaultFill, opacity: 1.0)
            }
            if highlighted.contains(.obliques) && !active.contains(.serratus) {
                result = result.highlight(.serratus, color: defaultFill, opacity: 1.0)
            }
        }
        return result
    }

    @ViewBuilder
    private func tooltipLabel(for muscle: Muscle) -> some View {
        if let target = isEditable ? muscle.editorTarget(on: side) : muscle.targetMuscle(on: side) {
            Text(target.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundColor(themeManager.primaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private func toggle(_ muscle: Muscle) {
        guard let target = muscle.editorTarget(on: side), let selectedMuscles else { return }
        if selectedMuscles.wrappedValue.contains(target) {
            selectedMuscles.wrappedValue.remove(target)
        } else {
            selectedMuscles.wrappedValue.insert(target)
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
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                panelColumn(side: .front, label: "FRONT")
                panelColumn(side: .back, label: "BACK")
            }
            .padding(.horizontal, 8)

            HStack(spacing: 16) {
                legendItem(
                    color: MuscleDisplayState.active.color,
                    label: isEditable ? "Selected" : "Worked Today"
                )
                if !isEditable {
                    legendItem(
                        color: MuscleDisplayState.resting.color,
                        label: "Recovering"
                    )
                }
                legendItem(
                    color: Color(
                        light: Color(red: 0.80, green: 0.85, blue: 0.92),
                        dark: Color(red: 0.12, green: 0.22, blue: 0.34)
                    ),
                    label: isEditable ? "Not Targeted" : "Rested"
                )
            }
            .padding(.top, 4)
        }
    }

    private func panelColumn(side: BodySide, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.secondaryText)
                .kerning(1.5)

            MuscleMapPanel(
                side: side,
                activatedMuscles: activatedMuscles,
                restingMuscles: restingMuscles,
                selectedMuscles: selectedMuscles,
                isEditable: isEditable
            )
            .environmentObject(themeManager)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeManager.secondaryText)
        }
    }
}

#Preview {
    MuscleDiagramView(
        activatedMuscles: [.chest, .frontDelts, .triceps, .abs, .serratus],
        restingMuscles: [.biceps, .lats, .upperBack, .traps],
        isEditable: false
    )
    .environmentObject(ThemeManager())
    .padding()
    .background(Color(red: 0.039, green: 0.078, blue: 0.117))
}
