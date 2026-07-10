//
//  ChatPageHeaderObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct ChatPageHeaderObserver: Observer {
    // MARK: - Type Aliases

    typealias R = ChatPageHeaderReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.sessionStoreDidChange,
    ]

    let viewModel: ViewModel<ChatPageHeaderReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ChatPageHeaderReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.sessionStoreDidChange:
            send(.updateAppearance)

        default: ()
        }
    }
}
