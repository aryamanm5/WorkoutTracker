//
//  AnimatedBodyView.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-10.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// A dedicated view for pulse animation on selected muscles, avoiding TimelineView generic inference issues.
struct PulseBodyView: View {
    let side: BodySide
    let highlights: [Muscle: MuscleHighlight]
    let style: BodyViewStyle
    let selectedMuscles: Set<Muscle>
    let pulseSpeed: Double
    let pulseRange: ClosedRange<Double>
    let onMuscleSelected: ((Muscle, MuscleSide) -> Void)?
    let tooltipContent: ((Muscle, MuscleSide) -> AnyView)?
    var hideSubGroups: Bool = true

    var body: some View {
        TimelineView(.animation) { timeline in
            PulseBodyCanvas(
                side: side,
                highlights: highlights,
                style: style,
                selectedMuscles: selectedMuscles,
                date: timeline.date,
                pulseSpeed: pulseSpeed,
                pulseRange: pulseRange,
                onMuscleSelected: onMuscleSelected,
                tooltipContent: tooltipContent,
                hideSubGroups: hideSubGroups
            )
        }
    }
}

/// Inner view that renders the pulsing canvas at a specific timestamp.
private struct PulseBodyCanvas: View {
    let side: BodySide
    let highlights: [Muscle: MuscleHighlight]
    let style: BodyViewStyle
    let selectedMuscles: Set<Muscle>
    let date: Date
    let pulseSpeed: Double
    let pulseRange: ClosedRange<Double>
    let onMuscleSelected: ((Muscle, MuscleSide) -> Void)?
    let tooltipContent: ((Muscle, MuscleSide) -> AnyView)?
    var hideSubGroups: Bool = true

    private var pulseFactor: Double {
        let elapsed = date.timeIntervalSinceReferenceDate
        let phase = (sin(elapsed * pulseSpeed * .pi * 2) + 1.0) / 2.0
        return pulseRange.lowerBound + phase * (pulseRange.upperBound - pulseRange.lowerBound)
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let renderer = BodyRenderer(
                    side: side,
                    highlights: highlights,
                    style: style,
                    selectedMuscles: selectedMuscles,
                    selectionPulseFactor: pulseFactor,
                    hideSubGroups: hideSubGroups
                )
                renderer.render(context: &context, size: size)
            }
            .contentShape(Rectangle())
            .overlay {
                InteractiveBodyOverlay(
                    side: side,
                    highlights: highlights,
                    style: style,
                    selectedMuscles: selectedMuscles,
                    size: geometry.size,
                    onMuscleSelected: onMuscleSelected,
                    hideSubGroups: hideSubGroups
                )
            }
            .overlay {
                if let tooltipContent, !selectedMuscles.isEmpty {
                    MuscleTooltipOverlay(
                        side: side,
                        highlights: highlights,
                        style: style,
                        selectedMuscles: selectedMuscles,
                        size: geometry.size,
                        content: tooltipContent,
                        hideSubGroups: hideSubGroups
                    )
                }
            }
            .overlay {
                BodyAccessibilityOverlay(
                    side: side,
                    highlights: highlights,
                    style: style,
                    selectedMuscles: selectedMuscles,
                    size: geometry.size,
                    onMuscleSelected: onMuscleSelected,
                    hideSubGroups: hideSubGroups
                )
            }
        }
    }
}
