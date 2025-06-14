//
//  GlassEffectViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public extension View {
    func glassEffect(
        isEnabled: Bool = true,
        padding edgePadding: CGFloat? = nil,
        shape: some Shape = .capsule,
        tint: Color? = nil
    ) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26, *) {
            if let edgePadding {
                padding(.all, edgePadding)
                    .glassEffect(
                        .regular.tint(tint),
                        in: shape,
                        isEnabled: isEnabled
                    )
                    .eraseToAnyView()
            } else {
                glassEffect(
                    .regular.tint(tint),
                    in: shape,
                    isEnabled: isEnabled
                )
                .eraseToAnyView()
            }
        } else {
            eraseToAnyView()
        }
        #else
        eraseToAnyView()
        #endif
    }
}
