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

    func makeBody(configuration: PrimitiveButtonStyle.Configuration) -> some View {
        ButtonView(configuration: configuration, isPressed: false)
    }
}
