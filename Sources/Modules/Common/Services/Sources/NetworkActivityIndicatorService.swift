//
//  NetworkActivityIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public struct NetworkActivityIndicatorService: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    private let defaultNetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()

    // MARK: - Methods

    public func hide() {
        defaultNetworkActivityIndicatorDelegate.hide()
    }

    public func show() {
        defaultNetworkActivityIndicatorDelegate.show()
        Observables.networkActivityOccurred.trigger()
    }
}
