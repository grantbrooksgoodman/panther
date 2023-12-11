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
    public let paths: NetworkPaths

    // MARK: - Init

    public init(environment: NetworkEnvironment, paths: NetworkPaths) {
        self.environment = environment
        self.paths = paths
    }
}
