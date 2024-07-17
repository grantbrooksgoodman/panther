//
//  SettingsPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct SettingsPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = SettingsPageReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.traitCollectionChanged]
    public let viewModel: ViewModel<R>

    // MARK: - Init

    public init(_ viewModel: ViewModel<R>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(SettingsPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value as? Nil != nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .traitCollectionChanged:
            send(.traitCollectionChanged)

        default: ()
        }
    }

    public func send(_ action: R.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
