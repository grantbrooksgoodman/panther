//
//  SplashPageObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 08/08/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct SplashPageObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = SplashPageReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.networkActivityOccurred]
    public let viewModel: ViewModel<SplashPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SplashPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(SplashPageObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        Logger.log(
            "\(observable.value as? Nil != nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .networkActivityOccurred:
            send(.bundleInitializationProgressOccurred)

        default: ()
        }
    }

    public func send(_ action: SplashPageReducer.Action) {
        Task { @MainActor in
            viewModel.send(action, animation: .easeIn)
        }
    }
}
