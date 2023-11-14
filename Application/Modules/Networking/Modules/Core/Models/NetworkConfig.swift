//
//  NetworkConfig.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkConfig {
    // MARK: - Properties

    public let environment: NetworkEnvironment

    // MARK: - Init

    public init(environment: NetworkEnvironment) {
        self.environment = environment
    }
}
