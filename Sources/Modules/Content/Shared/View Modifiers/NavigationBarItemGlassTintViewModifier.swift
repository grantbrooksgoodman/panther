//
//  NavigationBarItemGlassTintViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

private struct NavigationBarItemGlassTintViewModifier: ViewModifier {
    // MARK: - Properties

    private let color: Color
    private let placement: Set<NavigationBar.ItemPlacement>

    // MARK: - Init

    init(
        _ color: Color,
        for placement: Set<NavigationBar.ItemPlacement>
    ) {
        self.color = color
        self.placement = placement
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .onNavigationTransition(.didAppear) { _ in
                let color = UIColor(color)
                placement.forEach {
                    NavigationBar.setItemGlassTint(
                        color,
                        for: $0
                    )
                }
            }
    }
}

extension View {
    func navigationBarItemGlassTint(
        _ color: Color,
        for placement: NavigationBar.ItemPlacement
    ) -> some View {
        navigationBarItemGlassTint(
            color,
            for: [placement]
        )
    }

    func navigationBarItemGlassTint(
        _ color: Color,
        for placement: NavigationBar.ItemPlacement...
    ) -> some View {
        navigationBarItemGlassTint(
            color,
            for: Set(placement)
        )
    }

    func navigationBarItemGlassTint(
        _ color: Color,
        for placement: Set<NavigationBar.ItemPlacement>
    ) -> some View {
        modifier(
            NavigationBarItemGlassTintViewModifier(
                color,
                for: placement
            )
        )
    }
}
