//
//  RegionMenuObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public struct RegionMenuObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = RegionMenuReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.themedViewAppearanceChanged]
    public let viewModel: ViewModel<R>

    // MARK: - Init

    public init(_ viewModel: ViewModel<R>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(RegionMenuObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value as? Nil != nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .themedViewAppearanceChanged:
            Task { @MainActor in
                let previousQuery = viewModel.searchQuery
                send(.searchQueryChanged(" "))
                send(.searchQueryChanged(previousQuery.isBlank ? "" : previousQuery))
            }

        default: ()
        }
    }

    public func send(_ action: R.Action) {
        Task { @MainActor in
            viewModel.send(action)
        }
    }
}
