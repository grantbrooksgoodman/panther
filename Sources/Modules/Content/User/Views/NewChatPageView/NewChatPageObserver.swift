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

struct NewChatPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = NewChatPageReducer

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.firstMessageSentInNewChat,
        Observables.isNewChatPageDoneToolbarButtonEnabled,
        Observables.newChatPagePenPalsToolbarButtonAnimation,
    ]

    let viewModel: ViewModel<NewChatPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<NewChatPageReducer>) {
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
        case Observables.firstMessageSentInNewChat:
            send(.firstMessageSent)

        case Observables.isNewChatPageDoneToolbarButtonEnabled:
            send(.isDoneToolbarButtonEnabledChanged(
                Observables.isNewChatPageDoneToolbarButtonEnabled.value
            ))

        case Observables.newChatPagePenPalsToolbarButtonAnimation:
            sendWithAnimation(.animatePenPalsToolbarButtonBackgroundColor)

        default: ()
        }
    }

    // MARK: - Auxiliary

    private func sendWithAnimation(_ action: NewChatPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action, animation: .linear)
        }
    }
}
