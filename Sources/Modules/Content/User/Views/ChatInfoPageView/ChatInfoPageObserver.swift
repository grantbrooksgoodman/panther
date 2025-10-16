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

public struct ChatInfoPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = ChatInfoPageReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.currentConversationMetadataChanged]
    public let viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(ChatInfoPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .currentConversationMetadataChanged:
            send(.currentConversationMetadataChanged)

        default: ()
        }
    }

    public func send(_ action: ChatInfoPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
