//
//  NetworkActivityViewObserver.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class NetworkActivityViewObserver: Observer {
    // MARK: - Type Aliases

    public typealias R = NetworkActivityReducer

    // MARK: - Properties

    public let id = UUID()
    public let observedValues: [any ObservableProtocol] = [Observables.isNetworkActivityOccurring]
    public let viewModel: ViewModel<R>

    private var taskID = UUID()

    // MARK: - Init

    public init(_ viewModel: ViewModel<R>) {
        self.viewModel = viewModel
    }

    // MARK: - Observer Conformance

    public func linkObservables() {
        Observers.link(NetworkActivityViewObserver.self, with: observedValues)
    }

    public func onChange(of observable: Observable<Any>) {
        @Dependency(\.build) var build: Build
        @Dependency(\.coreKit.gcd) var coreGCD: CoreKit.GCD
        @Dependency(\.commonServices.haptics) var haptics: HapticsService

        Logger.log(
            "\(observable.value as? Nil != nil ? "Triggered" : "Observed change of") .\(observable.key.rawValue).",
            domain: .observer,
            metadata: [self, #file, #function, #line]
        )

        switch observable.key {
        case .isNetworkActivityOccurring:
            guard let value = observable.value as? Bool else { return }
            send(.isVisibleChanged(value))

            @Persistent(.indicatesNetworkActivity) var indicatesNetworkActivity: Bool?
            if build.stage != .generalRelease,
               build.developerModeEnabled,
               let indicatesNetworkActivity,
               indicatesNetworkActivity {
                haptics.generateFeedback(.medium)
            }

            let taskID = UUID()
            self.taskID = taskID

            coreGCD.after(.seconds(2)) {
                guard self.taskID == taskID,
                      !Observables.isNetworkActivityOccurring.value else { return }
                self.send(.isVisibleChanged(false))
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
