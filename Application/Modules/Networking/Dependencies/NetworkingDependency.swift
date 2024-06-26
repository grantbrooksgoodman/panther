//
//  NetworkingDependency.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum NetworkingDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> Networking {
        @Dependency(\.build) var build: Build
        @Dependency(\.commonServices.networkActivityIndicator) var networkActivityIndicatorService: NetworkActivityIndicatorService

        return .init(
            config: .init(
                environment: BuildConfig.networkEnvironment,
                paths: .init()
            ),
            delegates: .init(
                activityIndicator: networkActivityIndicatorService,
                connectionStatusProvider: build
            ),
            services: .init(
                conversation: .init(archive: .init()),
                core: .init(
                    auth: .init(),
                    database: .init(),
                    storage: .init()
                ),
                integrity: .init(),
                message: .init(
                    audio: .init(),
                    image: .init(),
                    legacy: .init()
                ),
                translation: .init(
                    archiver: .init(),
                    languageRecognition: .init(),
                    legacy: .init()
                ),
                user: .init(legacy: .init())
            )
        )
    }
}

public extension DependencyValues {
    var networking: Networking {
        get { self[NetworkingDependency.self] }
        set { self[NetworkingDependency.self] = newValue }
    }
}
