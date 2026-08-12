//
//  ComponentKit+SharedContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import ComponentKit

@MainActor
extension ComponentKit {
    /// Creates a toolbar done button styled with a checkmark symbol.
    ///
    /// Use this button in place of a textual done button when the app runs with full iOS 26
    /// compatibility.
    ///
    /// - Parameters:
    ///   - foregroundColor: The color of the button's symbol.
    ///   - action: The action to perform when the user taps the button.
    ///
    /// - Returns: A fixed-size button that displays a checkmark symbol and runs the given action.
    func v26DoneButton(
        foregroundColor: Color = .navigationBarButton,
        action: @escaping () -> Void
    ) -> some View {
        Components.button(
            symbolName: "checkmark",
            foregroundColor: foregroundColor,
            usesIntrinsicSize: false
        ) {
            action()
        }
        .frame(
            width: 32,
            height: 32
        )
    }
}
