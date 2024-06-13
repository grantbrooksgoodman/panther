//
//  NetworkDelegates.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkDelegates {
    // MARK: - Properties

    public let activityIndicator: NetworkActivityIndicator
    public let connectionStatusProvider: ConnectionStatusProvider

    // MARK: - Init

    public init(
        activityIndicator: NetworkActivityIndicator,
        connectionStatusProvider: ConnectionStatusProvider
    ) {
        self.activityIndicator = activityIndicator
        self.connectionStatusProvider = connectionStatusProvider
    }
}
