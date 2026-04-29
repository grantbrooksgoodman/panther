//
//  SettingsPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct SettingsPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = SettingsPageReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.didGrantAIEnhancedTranslationPermission,
        Observables.didGrantPenPalsPermission,
        Observables.traitCollectionChanged,
    ]

    let viewModel: ViewModel<SettingsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<SettingsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.didGrantAIEnhancedTranslationPermission:
            send(.aiEnhancedTranslationsSwitchToggled(
                on: Observables.didGrantAIEnhancedTranslationPermission.value
            ))

        case Observables.didGrantPenPalsPermission:
            send(.penPalsParticipantSwitchToggled(
                on: Observables.didGrantPenPalsPermission.value
            ))

        case Observables.traitCollectionChanged:
            send(.traitCollectionChanged)

        default: ()
        }
    }
}
