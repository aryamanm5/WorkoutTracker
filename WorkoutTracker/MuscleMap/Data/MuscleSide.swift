//
//  MuscleSide.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// Represents which side of the body a muscle belongs to.
public enum MuscleSide: String, CaseIterable, Codable, Sendable {
    case left
    case right
    case both
}

/// Represents which face of the body to display.
public enum BodySide: String, CaseIterable, Codable, Sendable {
    case front
    case back
}
