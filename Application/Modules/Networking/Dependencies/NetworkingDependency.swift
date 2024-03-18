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
        @Dependency(\.commonServices.networkActivityIndicator) var networkActivityIndicatorService: NetworkActivityIndicatorService

        return .init(
            activityIndicator: networkActivityIndicatorService,
            auth: .init(),
            config: .init(
                environment: BuildConfig.networkEnvironment,
                paths: .init()
            ),
            database: .init(),
            services: .init(
                conversation: .init(archive: .init()),
                message: .init(
                    audio: .init(),
                    legacy: .init()
                ),
                translation: .init(
                    archiver: .init(),
                    languageRecognition: .init(),
                    legacy: .init()
                ),
                user: .init(legacy: .init())
            ),
            storage: .init()
        )
    }
}

public extension DependencyValues {
    var networking: Networking {
        get { self[NetworkingDependency.self] }
        set { self[NetworkingDependency.self] = newValue }
    }
}
