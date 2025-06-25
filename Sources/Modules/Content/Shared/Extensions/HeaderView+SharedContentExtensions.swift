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

public extension HeaderView.PeripheralButtonType {
    static func v26DoneButton(_ action: @escaping () -> Void) -> HeaderView.PeripheralButtonType {
        .image(
            .init(
                image: .init(
                    foregroundColor: .navigationBarButton,
                    image: .init(systemName: "checkmark"),
                    size: .init(width: 22, height: 22),
                    weight: .semibold
                ),
            ) {
                action()
            }
        )
    }
}
