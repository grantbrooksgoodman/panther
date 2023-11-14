//
//  NetworkingDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
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
