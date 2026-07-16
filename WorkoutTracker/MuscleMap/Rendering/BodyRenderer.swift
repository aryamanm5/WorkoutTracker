//
//  BodyRenderer.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

struct BodyRenderer {

    let side: BodySide
    let highlights: [Muscle: MuscleHighlight]
    let style: BodyViewStyle
    let selectedMuscles: Set<Muscle>
    var selectionPulseFactor: Double = 1.0
    let hideSubGroups: Bool

    init(
        side: BodySide,
        highlights: [Muscle: MuscleHighlight],
        style: BodyViewStyle,
        selectedMuscles: Set<Muscle>,
        selectionPulseFactor: Double = 1.0,
        hideSubGroups: Bool = true
    ) {
        self.side = side
        self.highlights = highlights
        self.style = style
        self.selectedMuscles = selectedMuscles
        self.selectionPulseFactor = selectionPulseFactor
        self.hideSubGroups = hideSubGroups
    }

    // Shared across renderer instances — they are rebuilt every render pass,
    // so a per-instance cache would never hit.
    private static let pathCache = PathCache()

    /// ViewBox-to-view transform parameters for the given view size.
    private func layout(in size: CGSize) -> (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let viewBox = BodyPathProvider.viewBox(side: side)
        let scale = min(
            size.width / viewBox.size.width,
            size.height / viewBox.size.height
        )
        let offsetX = (size.width - viewBox.size.width * scale) / 2 - viewBox.origin.x * scale
        let offsetY = (size.height - viewBox.size.height * scale) / 2 - viewBox.origin.y * scale
        return (scale, offsetX, offsetY)
    }

    private func cachedPath(_ pathString: String, _ layout: (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat)) -> Path {
        Self.pathCache.path(for: pathString, scale: layout.scale, offsetX: layout.offsetX, offsetY: layout.offsetY)
    }

    func render(context: inout GraphicsContext, size: CGSize) {
        let layout = layout(in: size)
        let bodyParts = BodyPathProvider.paths(side: side)

        for bodyPart in bodyParts {
            if hideSubGroups, let m = bodyPart.muscle, m.isSubGroup, !m.isAlwaysVisibleSubGroup { continue }

            let muscle = bodyPart.muscle
            // Sub-groups inherit the parent's whole highlight (color AND
            // opacity) — inheriting only the color drew e.g. adductors as a
            // darker island inside a semi-transparent hamstring highlight.
            let highlight = muscle.flatMap { m in
                highlights[m] ?? m.parentGroup.flatMap { highlights[$0] }
            }
            let isSelected: Bool = {
                guard let m = muscle else { return false }
                if selectedMuscles.contains(m) { return true }
                // Always-visible sub-shapes can't be selected independently,
                // so they follow their parent's selection in every mode.
                if m.isAlwaysVisibleSubGroup, let parent = m.parentGroup {
                    return selectedMuscles.contains(parent)
                }
                return false
            }()

            let fill = resolveFill(for: bodyPart, highlight: highlight, isSelected: isSelected)

            let highlightOpacity = highlight?.opacity ?? 1.0
            let needsOpacityLayer = highlightOpacity < 1.0 && highlight != nil

            for pathString in bodyPart.allPaths {
                let path = cachedPath(pathString, layout)
                let opacityFactor = (isSelected && selectionPulseFactor != 1.0) ? selectionPulseFactor : 1.0

                if needsOpacityLayer || opacityFactor != 1.0 {
                    context.drawLayer { layerContext in
                        layerContext.opacity = (needsOpacityLayer ? highlightOpacity : 1.0) * opacityFactor
                        layerContext.fill(path, with: .color(fill))
                    }
                } else {
                    context.fill(path, with: .color(fill))
                }

                if style.strokeWidth > 0 {
                    context.stroke(
                        path,
                        with: .color(style.strokeColor),
                        lineWidth: style.strokeWidth
                    )
                }

                if isSelected {
                    context.stroke(
                        path,
                        with: .color(style.selectionStrokeColor),
                        lineWidth: style.selectionStrokeWidth
                    )
                }
            }
        }
    }

    /// Find which muscle was tapped at the given point.
    /// Sub-groups are tested before their parent groups.
    func hitTest(at point: CGPoint, in size: CGSize) -> (Muscle, MuscleSide)? {
        let layout = layout(in: size)
        let bodyParts = BodyPathProvider.paths(side: side)

        // Test sub-groups first so they take priority over parent groups
        let sortedParts = bodyParts.sorted { a, b in
            let aIsSub = a.muscle?.isSubGroup ?? false
            let bIsSub = b.muscle?.isSubGroup ?? false
            if aIsSub != bIsSub { return aIsSub }
            return false
        }

        for bodyPart in sortedParts {
            guard let muscle = bodyPart.muscle else { continue }
            if hideSubGroups && muscle.isSubGroup && !muscle.isAlwaysVisibleSubGroup { continue }

            // Always-visible sub-groups return parent when sub-groups are hidden
            let resolvedMuscle: Muscle
            if hideSubGroups && muscle.isAlwaysVisibleSubGroup, let parent = muscle.parentGroup {
                resolvedMuscle = parent
            } else {
                resolvedMuscle = muscle
            }

            for pathString in bodyPart.left {
                if cachedPath(pathString, layout).contains(point) { return (resolvedMuscle, .left) }
            }

            for pathString in bodyPart.right {
                if cachedPath(pathString, layout).contains(point) { return (resolvedMuscle, .right) }
            }

            for pathString in bodyPart.common {
                if cachedPath(pathString, layout).contains(point) { return (resolvedMuscle, .both) }
            }
        }

        return nil
    }

    /// Returns the bounding rect of a muscle's combined paths in the given view size.
    func boundingRect(for muscle: Muscle, in size: CGSize) -> CGRect? {
        let layout = layout(in: size)
        let bodyParts = BodyPathProvider.paths(side: side)
        var combinedRect: CGRect?

        for bodyPart in bodyParts {
            guard bodyPart.muscle == muscle else { continue }
            for pathString in bodyPart.allPaths {
                let rect = cachedPath(pathString, layout).boundingRect
                guard !rect.isEmpty else { continue }
                combinedRect = combinedRect?.union(rect) ?? rect
            }
        }

        return combinedRect
    }

    // MARK: - Private

    private func resolveFill(
        for bodyPart: BodyPartPathData,
        highlight: MuscleHighlight?,
        isSelected: Bool
    ) -> Color {
        guard let muscle = bodyPart.muscle else {
            return style.hairColor
        }
        if muscle == .head {
            return style.headColor
        }
        if isSelected {
            return style.selectionColor
        }
        if let highlight {
            return highlight.color
        }
        return style.defaultFillColor
    }
}
