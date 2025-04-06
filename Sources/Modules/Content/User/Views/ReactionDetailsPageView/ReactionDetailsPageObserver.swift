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

public struct ReactionDetailsPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = ReactionDetailsPageReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.currentConversationMetadataChanged]
    public let viewModel: ViewModel<ReactionDetailsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ReactionDetailsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(ReactionDetailsPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .currentConversationMetadataChanged:
            send(.updateViewID)

        default: ()
        }
    }

    public func send(_ action: ReactionDetailsPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
