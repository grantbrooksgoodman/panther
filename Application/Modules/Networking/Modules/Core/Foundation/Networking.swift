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

    public let auth: Auth
    public let config: NetworkConfig
    public let database: Database
    public let services: NetworkServices

    // MARK: - Init

    public init(
        auth: Auth,
        config: NetworkConfig,
        database: Database,
        services: NetworkServices
    ) {
        self.auth = auth
        self.config = config
        self.database = database
        self.services = services
    }
}
