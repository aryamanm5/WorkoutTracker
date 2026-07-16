//
//  BodyPathData.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// SVG path data for a single body part, supporting common, left, and right sub-paths.
/// `muscle` is nil for cosmetic hair paths.
struct BodyPartPathData {
    let muscle: Muscle?
    let common: [String]
    let left: [String]
    let right: [String]

    init(muscle: Muscle?, common: [String] = [], left: [String] = [], right: [String] = []) {
        self.muscle = muscle
        self.common = common
        self.left = left
        self.right = right
    }

    /// All SVG path strings combined.
    var allPaths: [String] {
        common + left + right
    }
}

/// ViewBox configuration for body rendering.
struct BodyViewBox {
    let origin: CGPoint
    let size: CGSize

    static let maleFront = BodyViewBox(
        origin: CGPoint(x: 0, y: 95),
        size: CGSize(width: 727, height: 1280)
    )

    static let maleBack = BodyViewBox(
        origin: CGPoint(x: 718, y: 95),
        size: CGSize(width: 727, height: 1280)
    )
}

/// Provides body path data for a given side.
struct BodyPathProvider {

    static func paths(side: BodySide) -> [BodyPartPathData] {
        side == .front ? MaleFrontPaths.paths : MaleBackPaths.paths
    }

    static func viewBox(side: BodySide) -> BodyViewBox {
        side == .front ? .maleFront : .maleBack
    }
}
