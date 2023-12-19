//
//  Networking.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct Networking {
    // MARK: - Properties

    public let activityIndicator: NetworkActivityIndicator
    public let auth: Auth
    public let config: NetworkConfig
    public let database: Database
    public let services: NetworkServices
    public let storage: Storage

    // MARK: - Init

    public init(
        activityIndicator: NetworkActivityIndicator,
        auth: Auth,
        config: NetworkConfig,
        database: Database,
        services: NetworkServices,
        storage: Storage
    ) {
        self.activityIndicator = activityIndicator
        self.auth = auth
        self.config = config
        self.database = database
        self.services = services
        self.storage = storage
    }
}
