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

public extension ComponentKit {
    func v26DoneButton(action: @escaping () -> Void) -> some View {
        Components.button(
            symbolName: "checkmark",
            foregroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : .accent,
            usesIntrinsicSize: false
        ) {
            action()
        }
        .frame(
            width: 30,
            height: 30
        )
    }
}
