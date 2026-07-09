//
//  ConversationCellObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 09/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct ConversationCellObserver: Observer {
    // MARK: - Type Aliases

    typealias R = ConversationCellReducer

    // MARK: - Types

    private enum TaskID: String {
        case refreshCellData
    }

    // MARK: - Properties

    let observedValues: [any ObservableProtocol] = [
        Observables.sessionStoreDidChange,
    ]

    let viewModel: ViewModel<ConversationCellReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ConversationCellReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        switch observable {
        case Observables.sessionStoreDidChange:
            @MainActorIsolated var conversationIDKey = viewModel.conversation.id.key
            Task.debounced(
                "\(String.fromCurrentEditorContext(sender: self))/\(conversationIDKey)/\(TaskID.refreshCellData.rawValue)",
                delay: .milliseconds(250)
            ) { @MainActor in
                send(.refreshCellData)
            }

        default: ()
        }
    }
}
