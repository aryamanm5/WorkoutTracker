//
//  BodyView.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// A SwiftUI view that renders a human body with highlighted muscles.
///
/// ```swift
/// BodyView(side: .front)
///     .highlight(.chest, color: .red)
///     .highlight(.biceps, color: .orange, opacity: 0.8)
///     .onMuscleSelected { muscle, side in
///         print("Tapped \(muscle.displayName) (\(side))")
///     }
/// ```
public struct BodyView: View {

    // MARK: - Properties

    private let side: BodySide
    private var style: BodyViewStyle
    private var highlights: [Muscle: MuscleHighlight]
    private var selectedMuscles: Set<Muscle> = []
    private var onMuscleSelected: ((Muscle, MuscleSide) -> Void)?

    // Pulse
    private var isPulseEnabled: Bool = false
    private var pulseSpeed: Double = 1.5
    private var pulseRange: ClosedRange<Double> = 0.6...1.0

    // Tooltip
    private var tooltipContent: ((Muscle, MuscleSide) -> AnyView)?

    // Sub-groups
    private var hideSubGroups: Bool = true

    // MARK: - Initializer

    /// Creates a body view.
    /// - Parameters:
    ///   - side: Front or back view (default: `.front`).
    ///   - style: Visual style configuration (default: `.default`).
    public init(
        side: BodySide = .front,
        style: BodyViewStyle = .default
    ) {
        self.side = side
        self.style = style
        self.highlights = [:]
    }

    // MARK: - Body

    public var body: some View {
        if isPulseEnabled && !selectedMuscles.isEmpty {
            pulseBody
        } else {
            standardBody
        }
    }

    // MARK: - Body Variants

    @ViewBuilder
    private var standardBody: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                makeRenderer().render(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .overlay {
                makeInteractiveOverlay(size: geometry.size)
            }
            .overlay {
                makeTooltipOverlay(size: geometry.size)
            }
            .overlay {
                makeAccessibilityOverlay(size: geometry.size)
            }
        }
    }

    @ViewBuilder
    private var pulseBody: some View {
        PulseBodyView(
            side: side,
            highlights: highlights,
            style: style,
            selectedMuscles: selectedMuscles,
            pulseSpeed: pulseSpeed,
            pulseRange: pulseRange,
            onMuscleSelected: onMuscleSelected,
            tooltipContent: tooltipContent,
            hideSubGroups: hideSubGroups
        )
    }

    // MARK: - Helpers

    private func makeRenderer() -> BodyRenderer {
        BodyRenderer(
            side: side,
            highlights: highlights,
            style: style,
            selectedMuscles: selectedMuscles,
            hideSubGroups: hideSubGroups
        )
    }

    private func makeInteractiveOverlay(size: CGSize) -> InteractiveBodyOverlay {
        InteractiveBodyOverlay(
            side: side,
            highlights: highlights,
            style: style,
            selectedMuscles: selectedMuscles,
            size: size,
            onMuscleSelected: onMuscleSelected,
            hideSubGroups: hideSubGroups
        )
    }

    private func makeAccessibilityOverlay(size: CGSize) -> BodyAccessibilityOverlay {
        BodyAccessibilityOverlay(
            side: side,
            highlights: highlights,
            style: style,
            selectedMuscles: selectedMuscles,
            size: size,
            onMuscleSelected: onMuscleSelected,
            hideSubGroups: hideSubGroups
        )
    }

    @ViewBuilder
    private func makeTooltipOverlay(size: CGSize) -> some View {
        if let tooltipContent, !selectedMuscles.isEmpty {
            MuscleTooltipOverlay(
                side: side,
                highlights: highlights,
                style: style,
                selectedMuscles: selectedMuscles,
                size: size,
                content: tooltipContent,
                hideSubGroups: hideSubGroups
            )
        }
    }
}

// MARK: - Modifiers

extension BodyView {

    /// Highlights a specific muscle with a color.
    public func highlight(_ muscle: Muscle, color: Color = .red, opacity: Double = 1.0) -> BodyView {
        var copy = self
        copy.highlights[muscle] = MuscleHighlight(muscle: muscle, color: color, opacity: opacity)
        return copy
    }

    /// Highlights multiple muscles with the same color.
    public func highlight(_ muscles: [Muscle], color: Color = .red, opacity: Double = 1.0) -> BodyView {
        var copy = self
        for muscle in muscles {
            copy.highlights[muscle] = MuscleHighlight(muscle: muscle, color: color, opacity: opacity)
        }
        return copy
    }

    /// Sets the selected muscle (single muscle).
    public func selected(_ muscle: Muscle?) -> BodyView {
        var copy = self
        copy.selectedMuscles = muscle.map { Set([$0]) } ?? []
        return copy
    }

    /// Sets multiple selected muscles (multi-select).
    public func selected(_ muscles: Set<Muscle>) -> BodyView {
        var copy = self
        copy.selectedMuscles = muscles
        return copy
    }

    /// Sets a callback for when a muscle is tapped.
    public func onMuscleSelected(_ action: @escaping (Muscle, MuscleSide) -> Void) -> BodyView {
        var copy = self
        copy.onMuscleSelected = action
        return copy
    }

    /// Adds a tooltip overlay that appears above selected muscles.
    public func tooltip<Content: View>(@ViewBuilder content: @escaping (Muscle, MuscleSide) -> Content) -> BodyView {
        var copy = self
        copy.tooltipContent = { muscle, side in AnyView(content(muscle, side)) }
        return copy
    }

    /// Applies a custom style.
    public func bodyStyle(_ style: BodyViewStyle) -> BodyView {
        var copy = self
        copy.style = style
        return copy
    }

    /// Shows sub-group muscle details (e.g. upperChest, lowerChest) instead of using only parent groups.
    /// Sub-groups are hidden by default.
    public func showSubGroups() -> BodyView {
        var copy = self
        copy.hideSubGroups = false
        return copy
    }

    /// Enables pulse animation on the selected muscle.
    public func pulseSelected(speed: Double = 1.5, range: ClosedRange<Double> = 0.6...1.0) -> BodyView {
        var copy = self
        copy.isPulseEnabled = true
        copy.pulseSpeed = speed
        copy.pulseRange = range
        return copy
    }
}

// MARK: - Preview

#Preview("Male Front") {
    BodyView(side: .front)
        .highlight(.chest, color: .red)
        .highlight(.biceps, color: .orange, opacity: 0.8)
        .highlight(.abs, color: .yellow, opacity: 0.6)
        .highlight(.quadriceps, color: .red)
        .frame(width: 200, height: 400)
        .padding()
}

#Preview("Male Back") {
    BodyView(side: .back)
        .highlight(.trapezius, color: .orange)
        .highlight(.upperBack, color: .red)
        .highlight(.hamstring, color: .red)
        .frame(width: 200, height: 400)
        .padding()
}
