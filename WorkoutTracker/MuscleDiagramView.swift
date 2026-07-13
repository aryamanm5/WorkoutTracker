import SwiftUI

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
    let intensities: [TargetMuscle: Double]
    var selectedMuscles: Binding<Set<TargetMuscle>>?
    let isEditable: Bool

    @EnvironmentObject var themeManager: ThemeManager

    private var style: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: defaultFill,
            strokeColor: themeManager.cardBorder,
            strokeWidth: 0.55,
            selectionColor: .appAccent,
            selectionStrokeColor: Color.appGradientEnd,
            selectionStrokeWidth: 1.6,
            headColor: Color(
                light: Color(red: 0.87, green: 0.84, blue: 0.80),
                dark: Color(red: 0.26, green: 0.24, blue: 0.21)
            ),
            hairColor: Color(
                light: Color(red: 0.35, green: 0.32, blue: 0.29),
                dark: Color(red: 0.10, green: 0.09, blue: 0.08)
            ),
            shadowColor: .clear,
            shadowRadius: 0,
            shadowOffset: .zero
        )
    }

    private var defaultFill: Color {
        Color(
            light: Color(red: 0.90, green: 0.88, blue: 0.84),
            dark: Color(red: 0.22, green: 0.20, blue: 0.18)
        )
    }

    /// Per-region intensity: the hottest contributing target muscle wins.
    private var mappedIntensities: [Muscle: Double] {
        var result: [Muscle: Double] = [:]
        for (target, intensity) in intensities where intensity > 0.01 {
            for muscle in target.mapMuscles(on: side) {
                result[muscle] = max(result[muscle] ?? 0, intensity)
            }
        }
        return result
    }

    var body: some View {
        configuredBodyView
            .aspectRatio(CGSize(width: 250, height: 520), contentMode: .fit)
    }

    private var configuredBodyView: BodyView {
        var bodyView = BodyView(gender: .male, side: side, style: style)
            .showSubGroups()

        if isEditable, let selectedMuscles {
            let selected = Set(selectedMuscles.wrappedValue.flatMap { $0.mapMuscles(on: side) })
            bodyView = bodyView.selected(selected)
            bodyView = applySubGroupMasks(to: bodyView, highlighted: selected)
        } else {
            let mapped = mappedIntensities
            for (muscle, intensity) in mapped {
                bodyView = bodyView.highlight(
                    muscle,
                    color: Color.heat(intensity),
                    opacity: 0.55 + 0.4 * intensity
                )
            }
            bodyView = applySubGroupMasks(to: bodyView, highlighted: Set(mapped.keys))
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
    private func applySubGroupMasks(to bodyView: BodyView, highlighted: Set<Muscle>) -> BodyView {
        var result = bodyView
        if side == .front {
            if highlighted.contains(.deltoids) && !highlighted.contains(.frontDeltoid) {
                result = result.highlight(.frontDeltoid, color: defaultFill, opacity: 1.0)
            }
            if highlighted.contains(.obliques) && !highlighted.contains(.serratus) {
                result = result.highlight(.serratus, color: defaultFill, opacity: 1.0)
            }
        }
        return result
    }

    @ViewBuilder
    private func tooltipLabel(for muscle: Muscle) -> some View {
        if let target = isEditable ? muscle.editorTarget(on: side) : muscle.targetMuscle(on: side) {
            VStack(spacing: 2) {
                Text(target.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(themeManager.primaryText)
                if !isEditable {
                    Text(TrainingEngine.RecoveryStatus.from(fatigue: intensities[target] ?? 0).rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(themeManager.secondaryText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func toggle(_ muscle: Muscle) {
        guard let target = muscle.editorTarget(on: side), let selectedMuscles else { return }
        if selectedMuscles.wrappedValue.contains(target) {
            selectedMuscles.wrappedValue.remove(target)
            Haptics.shared.play(.toggleOff)
        } else {
            selectedMuscles.wrappedValue.insert(target)
            Haptics.shared.play(.toggleOn)
        }
    }
}

/// Front + back body heatmap. In display mode, pass per-muscle intensities
/// (0 = fresh, 1 = just trained / fully fatigued) and the fill interpolates
/// along the heat scale. In edit mode, pass a selection binding instead.
struct MuscleDiagramView: View {
    var intensities: [TargetMuscle: Double] = [:]
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

            legend
        }
    }

    @ViewBuilder
    private var legend: some View {
        if isEditable {
            HStack(spacing: 16) {
                legendItem(color: .appAccent, label: "Selected")
                legendItem(
                    color: Color(
                        light: Color(red: 0.90, green: 0.88, blue: 0.84),
                        dark: Color(red: 0.22, green: 0.20, blue: 0.18)
                    ),
                    label: "Not Targeted"
                )
            }
            .padding(.top, 4)
        } else {
            HStack(spacing: 8) {
                Text("Fresh")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
                LinearGradient(
                    colors: [Color.heat(0.05), Color.heat(0.5), Color.heat(1.0)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 110, height: 8)
                .clipShape(Capsule())
                Text("Fatigued")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.secondaryText)
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
                intensities: intensities,
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
        intensities: [
            .chest: 1.0, .frontDelts: 0.9, .triceps: 0.85,
            .lats: 0.45, .upperBack: 0.4, .biceps: 0.35,
            .quads: 0.15, .calves: 0.1
        ]
    )
    .environmentObject(ThemeManager())
    .padding()
    .background(Color.appBackground)
}
