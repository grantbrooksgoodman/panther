//
//  NetworkConfig.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
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
