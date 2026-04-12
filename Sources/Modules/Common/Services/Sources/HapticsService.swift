//
//  HapticsService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

@MainActor
struct HapticsService {
    // MARK: - Types

    enum HapticFeedbackStyle {
        case heavy
        case light
        case medium
        case rigid
        case selection
        case soft
    }

    // MARK: - Methods

    func generateFeedback(_ style: HapticFeedbackStyle) {
        switch style {
        case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .rigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .soft: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}
