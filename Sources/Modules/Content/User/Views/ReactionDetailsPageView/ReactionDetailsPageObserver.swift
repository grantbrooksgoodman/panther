//
//  ReactionDetailsPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct ReactionDetailsPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = ReactionDetailsPageReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [Observables.currentConversationMetadataChanged]
    let viewModel: ViewModel<ReactionDetailsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ReactionDetailsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.currentConversationMetadataChanged:
            send(.updateViewID)

        default: ()
        }
    }
}
