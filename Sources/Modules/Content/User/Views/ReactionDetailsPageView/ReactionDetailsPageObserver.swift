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

    let id = UUID()
    let observedValues: [any ObservableProtocol] = [Observables.currentConversationMetadataChanged]
    let viewModel: ViewModel<ReactionDetailsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ReactionDetailsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func linkObservables() {
        Observers.link(ReactionDetailsPageObserver.self, with: observedValues)
    }

    func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .currentConversationMetadataChanged:
            send(.updateViewID)

        default: ()
        }
    }

    func send(_ action: ReactionDetailsPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
