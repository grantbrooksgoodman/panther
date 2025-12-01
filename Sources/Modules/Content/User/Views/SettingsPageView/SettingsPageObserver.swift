//
//  SettingsPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct SettingsPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = SettingsPageReducer

    // MARK: - Properties

    let id = UUID()
    let observedValues: [any ObservableProtocol] = [
        Observables.didGrantPenPalsPermission,
        Observables.traitCollectionChanged,
    ]
    let viewModel: ViewModel<R>

    // MARK: - Init

    init(_ viewModel: ViewModel<R>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func linkObservables() {
        Observers.link(SettingsPageObserver.self, with: observedValues)
    }

    func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .didGrantPenPalsPermission:
            guard let value = observable.value as? Bool else { return }
            send(.penPalsParticipantSwitchToggled(on: value))

        case .traitCollectionChanged:
            send(.traitCollectionChanged)

        default: ()
        }
    }

    func send(_ action: R.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
