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

    public let config: NetworkConfig
    public let delegates: NetworkDelegates
    public let services: NetworkServices

    // MARK: - Computed Properties

    public var auth: Auth { services.core.auth }
    public var database: Database { services.core.database }
    public var storage: Storage { services.core.storage }

    // MARK: - Init

    public init(
        config: NetworkConfig,
        delegates: NetworkDelegates,
        services: NetworkServices
    ) {
        self.config = config
        self.delegates = delegates
        self.services = services
    }
}
