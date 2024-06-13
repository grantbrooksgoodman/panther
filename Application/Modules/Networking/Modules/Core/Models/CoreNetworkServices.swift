//
//  CoreNetworkServices.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct CoreNetworkServices {
    // MARK: - Properties

    public let auth: Auth
    public let database: Database
    public let storage: Storage

    // MARK: - Init

    public init(
        auth: Auth,
        database: Database,
        storage: Storage
    ) {
        self.auth = auth
        self.database = database
        self.storage = storage
    }
}
