//
//  Muscle.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// Represents all available muscle groups that can be highlighted on the body.
public enum Muscle: String, CaseIterable, Codable, Identifiable, Sendable {
    case abs
    case biceps
    case calves
    case chest
    case deltoids
    case feet
    case forearm
    case gluteal
    case hamstring
    case hands
    case head
    case knees
    case lowerBack = "lower-back"
    case obliques
    case quadriceps
    case tibialis
    case trapezius
    case triceps
    case upperBack = "upper-back"

    // New muscle groups
    case rotatorCuff = "rotator-cuff"
    case serratus
    case rhomboids

    // Sub-groups
    case ankles
    case adductors
    case neck
    case hipFlexors = "hip-flexors"
    case upperChest = "upper-chest"
    case lowerChest = "lower-chest"
    case innerQuad = "inner-quad"
    case outerQuad = "outer-quad"
    case upperAbs = "upper-abs"
    case lowerAbs = "lower-abs"
    case frontDeltoid = "front-deltoid"
    case rearDeltoid = "rear-deltoid"
    case upperTrapezius = "upper-trapezius"
    case lowerTrapezius = "lower-trapezius"

    public var id: String { rawValue }

    /// Human-readable display name, derived from the raw value ("lower-back" → "Lower Back").
    public var displayName: String {
        rawValue.split(separator: "-").map(\.capitalized).joined(separator: " ")
    }

    /// Whether this is a cosmetic part (head/hair) rather than a muscle.
    public var isCosmeticPart: Bool {
        self == .head
    }

    /// The parent muscle group, if this muscle is a sub-group.
    public var parentGroup: Muscle? {
        switch self {
        case .upperChest, .lowerChest: return .chest
        case .innerQuad, .outerQuad, .hipFlexors: return .quadriceps
        case .upperAbs, .lowerAbs: return .abs
        case .frontDeltoid, .rearDeltoid: return .deltoids
        case .upperTrapezius, .lowerTrapezius: return .trapezius
        case .serratus: return .obliques
        case .ankles: return .feet
        case .adductors: return .hamstring
        case .neck: return .head
        default: return nil
        }
    }

    /// Whether this muscle is a sub-group of another muscle.
    public var isSubGroup: Bool {
        parentGroup != nil
    }

    /// Whether this sub-group is always rendered even when sub-groups are hidden.
    /// When tapped in default mode, the parent muscle is returned instead.
    public var isAlwaysVisibleSubGroup: Bool {
        switch self {
        case .ankles, .adductors, .neck: return true
        default: return false
        }
    }
}
