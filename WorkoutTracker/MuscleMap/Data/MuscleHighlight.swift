//
//  MuscleHighlight.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// Data model for a highlighted muscle with color and opacity.
public struct MuscleHighlight: Sendable, Equatable {
    public let muscle: Muscle
    public let color: Color
    public let opacity: Double

    public init(muscle: Muscle, color: Color, opacity: Double = 1.0) {
        self.muscle = muscle
        self.color = color
        self.opacity = opacity
    }
}
