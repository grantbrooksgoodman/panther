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

    // MARK: - Properties

    static let shared = HapticsService()

    private let heavyImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let lightImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    private let softImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    /// Plays haptic feedback of the given style.
    ///
    /// - Parameter style: The kind of haptic feedback to play.
    func generateFeedback(_ style: HapticFeedbackStyle) {
        switch style {
        case .heavy: heavyImpactFeedbackGenerator.impactOccurred()
        case .light: lightImpactFeedbackGenerator.impactOccurred()
        case .medium: mediumImpactFeedbackGenerator.impactOccurred()
        case .rigid: rigidImpactFeedbackGenerator.impactOccurred()
        case .selection: selectionFeedbackGenerator.selectionChanged()
        case .soft: softImpactFeedbackGenerator.impactOccurred()
        }
    }

    /// Prepares the given style generator to receive events.
    ///
    /// - Parameter generatorStyle: The style of generator to prepare.
    func prepare(_ generatorStyle: HapticFeedbackStyle) {
        switch generatorStyle {
        case .heavy: heavyImpactFeedbackGenerator.prepare()
        case .light: lightImpactFeedbackGenerator.prepare()
        case .medium: mediumImpactFeedbackGenerator.prepare()
        case .rigid: rigidImpactFeedbackGenerator.prepare()
        case .selection: selectionFeedbackGenerator.prepare()
        case .soft: softImpactFeedbackGenerator.prepare()
        }
    }
}
