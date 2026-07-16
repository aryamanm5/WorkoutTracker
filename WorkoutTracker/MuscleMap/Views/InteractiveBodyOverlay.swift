//
//  InteractiveBodyOverlay.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-10.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// A transparent overlay that handles tap interaction for a body canvas,
/// performing hit testing against the muscle paths.
struct InteractiveBodyOverlay: View {

    let side: BodySide
    let highlights: [Muscle: MuscleHighlight]
    let style: BodyViewStyle
    let selectedMuscles: Set<Muscle>
    let size: CGSize
    let onMuscleSelected: ((Muscle, MuscleSide) -> Void)?
    var hideSubGroups: Bool = true

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    handleTap(at: value.location)
                }
            )
    }

    private func handleTap(at location: CGPoint) {
        guard onMuscleSelected != nil else { return }
        let renderer = BodyRenderer(
            side: side,
            highlights: highlights,
            style: style,
            selectedMuscles: selectedMuscles,
            hideSubGroups: hideSubGroups
        )
        if let (muscle, muscleSide) = renderer.hitTest(at: location, in: size) {
            onMuscleSelected?(muscle, muscleSide)
        }
    }
}
