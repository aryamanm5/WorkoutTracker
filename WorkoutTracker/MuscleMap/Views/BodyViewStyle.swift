//
//  BodyViewStyle.swift
//  MuscleMap
//
//  Created by Melih Colpan on 2026-02-09.
//  Copyright © 2026 Melih Colpan. All rights reserved.
//  Licensed under the MIT License.
//

import SwiftUI

/// Configuration for the visual appearance of a BodyView.
public struct BodyViewStyle: Sendable {
    public var defaultFillColor: Color
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    public var selectionColor: Color
    public var selectionStrokeColor: Color
    public var selectionStrokeWidth: CGFloat
    public var headColor: Color
    public var hairColor: Color

    public init(
        defaultFillColor: Color = Color(white: 0.78),
        strokeColor: Color = .clear,
        strokeWidth: CGFloat = 0,
        selectionColor: Color = .green,
        selectionStrokeColor: Color = .green,
        selectionStrokeWidth: CGFloat = 2,
        headColor: Color = Color(white: 0.75),
        hairColor: Color = Color(white: 0.25)
    ) {
        self.defaultFillColor = defaultFillColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.selectionColor = selectionColor
        self.selectionStrokeColor = selectionStrokeColor
        self.selectionStrokeWidth = selectionStrokeWidth
        self.headColor = headColor
        self.hairColor = hairColor
    }

    /// Default style with gray fill and green selection.
    public static let `default` = BodyViewStyle()
}
