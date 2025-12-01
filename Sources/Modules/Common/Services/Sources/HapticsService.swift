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

    // MARK: - Properties

    // UIImpactFeedbackGenerator
    private let heavyImpactFeedbackGenerator: UIImpactFeedbackGenerator
    private let lightImpactFeedbackGenerator: UIImpactFeedbackGenerator
    private let mediumImpactFeedbackGenerator: UIImpactFeedbackGenerator
    private let rigidImpactFeedbackGenerator: UIImpactFeedbackGenerator
    private let softImpactFeedbackGenerator: UIImpactFeedbackGenerator

    // UISelectionFeedbackGenerator
    private let selectionFeedbackGenerator: UISelectionFeedbackGenerator

    // MARK: - Init

    init(
        heavyImpactFeedbackGenerator: UIImpactFeedbackGenerator,
        lightImpactFeedbackGenerator: UIImpactFeedbackGenerator,
        mediumImpactFeedbackGenerator: UIImpactFeedbackGenerator,
        rigidImpactFeedbackGenerator: UIImpactFeedbackGenerator,
        selectionFeedbackGenerator: UISelectionFeedbackGenerator,
        softImpactFeedbackGenerator: UIImpactFeedbackGenerator
    ) {
        self.heavyImpactFeedbackGenerator = heavyImpactFeedbackGenerator
        self.lightImpactFeedbackGenerator = lightImpactFeedbackGenerator
        self.mediumImpactFeedbackGenerator = mediumImpactFeedbackGenerator
        self.rigidImpactFeedbackGenerator = rigidImpactFeedbackGenerator
        self.selectionFeedbackGenerator = selectionFeedbackGenerator
        self.softImpactFeedbackGenerator = softImpactFeedbackGenerator
    }

    // MARK: - Methods

    func generateFeedback(_ style: HapticFeedbackStyle) {
        Task { @MainActor in
            switch style {
            case .heavy:
                heavyImpactFeedbackGenerator.impactOccurred()

            case .light:
                lightImpactFeedbackGenerator.impactOccurred()

            case .medium:
                mediumImpactFeedbackGenerator.impactOccurred()

            case .rigid:
                rigidImpactFeedbackGenerator.impactOccurred()

            case .selection:
                selectionFeedbackGenerator.selectionChanged()

            case .soft:
                softImpactFeedbackGenerator.impactOccurred()
            }
        }
    }
}
