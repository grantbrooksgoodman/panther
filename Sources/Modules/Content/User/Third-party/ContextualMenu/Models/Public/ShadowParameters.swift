//
//  ShadowParameters.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import CoreGraphics
import Foundation

struct ShadowParameters {
    // MARK: - Properties

    static let none: ShadowParameters = .init(opacity: 0)

    var color: CGColor
    var offset: CGSize
    var opacity: Float
    var radius: CGFloat

    // MARK: - Init

    init(
        color: CGColor = .init(red: 0, green: 0, blue: 0, alpha: 0),
        offset: CGSize = .init(width: 0, height: 1),
        radius: CGFloat = 5,
        opacity: Float = 0
    ) {
        self.color = color
        self.offset = offset
        self.radius = radius
        self.opacity = opacity
    }
}
