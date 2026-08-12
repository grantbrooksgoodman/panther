//
//  HeaderView+SharedContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

@MainActor
extension HeaderView.PeripheralButtonType {
    /// Creates a header done button styled with a checkmark symbol.
    ///
    /// Use this button in place of a textual done button when the app runs with full iOS 26
    /// compatibility.
    ///
    /// - Parameter action: The action to perform when the user taps the button.
    ///
    /// - Returns: A header button that displays a checkmark symbol and runs the given action.
    static func v26DoneButton(_ action: @escaping () -> Void) -> HeaderView.PeripheralButtonType {
        .image(
            .init(
                image: .init(
                    foregroundColor: .navigationBarButton,
                    image: .init(systemName: "checkmark"),
                    size: .init(width: 22, height: 22),
                    weight: .semibold
                )
            ) {
                action()
            }
        )
    }
}
