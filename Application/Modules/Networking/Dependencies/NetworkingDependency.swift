//
//  NetworkingDependency.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum NetworkingDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> Networking {
        .init(
            auth: .init(),
            config: .init(environment: BuildConfig.networkEnvironment),
            database: .init(),
            services: .init()
        )
    }
}

public extension DependencyValues {
    var networking: Networking {
        get { self[NetworkingDependency.self] }
        set { self[NetworkingDependency.self] = newValue }
    }
}
