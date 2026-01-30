//
//  FeaturePermissionPageViewConfiguration+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension FeaturePermissionPageView.Configuration {
    static var penPals: FeaturePermissionPageView.Configuration {
        .init(
            titleText: "Introducing ⌘PenPals⌘", // swiftlint:disable:next line_length
            subtitleText: "⌘PenPals⌘ enables cross-cultural communication between users of different languages.\n\nEnabling this feature allows you to connect fluently with a randomly-selected person at any time. In turn, your account will be entered into the pool of available ⌘PenPals⌘ for other people to connect with. ⌘PenPals⌘ cannot view each other’s phone numbers unless explicitly allowed.\n\nYour participation in ⌘PenPals⌘ can be toggled at any time via Settings.",
            accentColor: .purple,
            iconConfig: .penPalsIcon(includesShadow: true),
            enableButtonAction: {
                Task {
                    @Dependency(\.commonServices.penPals) var penPalsService: PenPalsService
                    if let exception = await penPalsService.setDidGrantPenPalsPermission(true) {
                        Logger.log(
                            exception,
                            domain: .penPals,
                            with: .toastInPrerelease
                        )
                    }
                }
            },
            declineButtonAction: {
                Observables.didGrantPenPalsPermission.value = false
            }
        )
    }

    static var aiEnhancedTranslations: FeaturePermissionPageView.Configuration {
        .init(
            titleText: "AI-Enhanced Translations", // swiftlint:disable:next line_length
            subtitleText: "Make translations feel more natural across languages.\n\nWhen enabled, an obfuscated version of your message may be sent to a large language model (LLM) to refine the translation. Personal identifiers are removed or masked before processing, and only what’s needed to improve the result is shared.\n\nYou can turn this feature on or off at any time via Settings.",
            accentColor: .init(uiColor: .systemBlue),
            iconConfig: .aiEnhancedTranslationsIcon(includesShadow: true),
            enableButtonAction: {
                Task {
                    @Dependency(\.commonServices.aiEnhancedTranslation) var aiEnhancedTranslationService: AIEnhancedTranslationService
                    if let exception = await aiEnhancedTranslationService.setDidGrantAIEnhancedTranslationPermission(true) {
                        Logger.log(
                            exception,
                            with: .toastInPrerelease
                        )
                    }
                }
            },
            declineButtonAction: {
                Observables.didGrantAIEnhancedTranslationPermission.value = false
            }
        )
    }
}
