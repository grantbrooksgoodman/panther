//
//  UserContentContainerObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/04/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct UserContentContainerObserver: Observer {
    // MARK: - Type Aliases

    typealias R = UserContentContainerReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.currentConversationMetadataChanged,
    ]

    let viewModel: ViewModel<UserContentContainerReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<UserContentContainerReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.currentConversationMetadataChanged:
            send(.conversationMetadataChanged)

        default: ()
        }
    }
}
