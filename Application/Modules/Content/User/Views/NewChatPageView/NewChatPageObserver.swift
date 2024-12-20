//
//  NewChatPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public struct NewChatPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = NewChatPageReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [
        Observables.contactSelectorPresentationPending,
        Observables.firstMessageSentInNewChat,
        Observables.isNewChatPageDoneToolbarButtonEnabled,
    ]
    public let viewModel: ViewModel<NewChatPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<NewChatPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(NewChatPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .contactSelectorPresentationPending:
            send(.isPresentingContactSelectorSheetChanged(true))

        case .firstMessageSentInNewChat:
            send(.firstMessageSent)

        case .isNewChatPageDoneToolbarButtonEnabled:
            guard let value = observable.value as? Bool else { return }
            send(.isDoneToolbarButtonEnabledChanged(value))

        default: ()
        }
    }

    public func send(_ action: NewChatPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
