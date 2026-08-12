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

/// Use ``HapticsService`` to play haptic feedback.
@MainActor
struct HapticsService {
    // MARK: - Types

    /// The kind of haptic feedback to play.
    enum HapticFeedbackStyle {
        /// Impact feedback between large, heavy interface elements.
        case heavy

        /// Impact feedback between small, light interface elements.
        case light

        /// Impact feedback between moderately sized interface elements.
        case medium

        /// Impact feedback between hard or inflexible interface elements.
        case rigid

        /// Feedback indicating a change in selection.
        case selection

        /// Impact feedback between soft or flexible interface elements.
        case soft
    }

    // MARK: - Methods

    /// Plays haptic feedback of the given style.
    ///
    /// - Parameter style: The kind of haptic feedback to play.
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
