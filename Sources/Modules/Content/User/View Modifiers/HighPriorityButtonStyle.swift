//
//  HighPriorityButtonStyle.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/// A button style that triggers with a high-priority gesture.
///
/// Use ``HighPriorityButtonStyle`` for buttons nested inside other tappable areas, so their
/// taps win over the enclosing gesture. The label dims while pressed, and the action triggers
/// only for taps with minimal movement.
struct HighPriorityButtonStyle: PrimitiveButtonStyle {
    private struct ButtonView: View {
        /* MARK: Properties */

        private let configuration: PrimitiveButtonStyle.Configuration
        @State private var isPressed: Bool = false

        /* MARK: Init */

        init(
            configuration: PrimitiveButtonStyle.Configuration,
            isPressed: Bool
        ) {
            self.configuration = configuration
            self.isPressed = isPressed
        }

        /* MARK: View */

        var body: some View {
            let gesture = DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { value in
                    isPressed = false
                    guard value.translation.width < 10,
                          value.translation.height < 10 else { return }
                    configuration.trigger()
                }

            return configuration.label
                .opacity(isPressed ? 0.5 : 1.0)
                .highPriorityGesture(gesture)
        }
    }

    // MARK: - Make Body

    /// Creates the view for the button's body.
    func makeBody(configuration: PrimitiveButtonStyle.Configuration) -> some View {
        ButtonView(configuration: configuration, isPressed: false)
    }
}
