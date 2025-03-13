//
//  RoundedCornersViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

private struct RoundedCornersViewModifier: Shape {
    // MARK: - Properties

    private let corners: UIRectCorner
    private let radius: CGFloat

    // MARK: - Init

    public init(radius: CGFloat, corners: UIRectCorner) {
        self.radius = radius
        self.corners = corners
    }

    // MARK: - Path

    public func path(in rect: CGRect) -> Path {
        .init(
            UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners,
                cornerRadii: CGSize(width: radius, height: radius)
            ).cgPath
        )
    }
}

public extension View {
    func roundedCorners(
        _ radius: CGFloat = .infinity,
        corners: UIRectCorner = .allCorners
    ) -> some View {
        clipShape(RoundedCornersViewModifier(radius: radius, corners: corners))
    }
}
