//
//  SplashPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/08/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

struct SplashPageObserver: Observer {
    // MARK: - Type Aliases

    typealias R = SplashPageReducer

    // MARK: - Properties

    let id = UUID()
    let observedValues: [any ObservableProtocol] = [Observables.networkActivityOccurred]
    let viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<SplashPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value is Nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            sender: self
        )

        switch observable.key {
        case .networkActivityOccurred:
            send(.bundleInitializationProgressOccurred)

        default: ()
        }
    }

    func send(_ action: SplashPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action, animation: .easeIn)
        }
    }
}
