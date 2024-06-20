//
//  ComponentKit+CoreExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import ComponentKit
import CoreArchitecture

public extension ComponentKit {
    func button(
        _ text: String,
        font: ComponentKit.Font = .system,
        action: @escaping () -> Void
    ) -> some View {
        @Dependency(\.componentKit) var components: ComponentKit
        return components.button(text, font: font, foregroundColor: .accent, action: action)
    }

    func symbol(_ systemName: String, usesIntrinsicSize: Bool = true) -> some View {
        @Dependency(\.componentKit) var components: ComponentKit
        return components.symbol(systemName, foregroundColor: .accent, usesIntrinsicSize: usesIntrinsicSize)
    }

    func text(_ text: String, font: ComponentKit.Font = .system) -> some View {
        @Dependency(\.componentKit) var components: ComponentKit
        return components.text(text, font: font, foregroundColor: .titleText)
    }
}
