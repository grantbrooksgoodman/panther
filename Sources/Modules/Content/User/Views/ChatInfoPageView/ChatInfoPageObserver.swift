//
//  ChatInfoPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct ChatInfoPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = ChatInfoPageReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.chatInfoPageLoadingStateUpdated,
        Observables.currentConversationActivityChanged,
        Observables.currentConversationMetadataChanged,
    ]

    let viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") \(observable).",
            domain: .observer,
            sender: self
        )

        switch observable {
        case Observables.chatInfoPageLoadingStateUpdated:
            send(.loadingStateUpdated)

        case Observables.currentConversationActivityChanged:
            send(.viewAppeared)

        case Observables.currentConversationMetadataChanged:
            send(.currentConversationMetadataChanged)

        default: ()
        }
    }
}
