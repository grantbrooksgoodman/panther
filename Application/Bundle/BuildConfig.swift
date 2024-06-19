//
//  BuildConfig.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum BuildConfig {
    // MARK: - Flags

    public static let loggingEnabled = false
    public static let timebombActive = false

    // MARK: - Names

    public static let codeName = "Panther"
    public static let finalName = "Hello"

    // MARK: - Versioning

    public static let appStoreReleaseVersion = 2
    public static let dmyFirstCompileDateString = "11112023"
    public static let stage: Build.Stage = .generalRelease

    // MARK: - Other

    public static let languageCode = Locale.systemLanguageCode
    public static let loggerDomainsExcludedFromSessionRecord: [LoggerDomain] = [
        .observer,
    ]
    public static let loggerDomainSubscriptions: [LoggerDomain] = [
        .bugPrevention,
        .chatPageState,
        .contacts,
        .conversation,
        .general,
        .notifications,
        .queue,
        .user,
        .userSession,
    ]

    public static var networkEnvironment: NetworkEnvironment {
        @Persistent(.networkEnvironment) var networkEnvironment: NetworkEnvironment?
        networkEnvironment = networkEnvironment ?? .production
        return networkEnvironment ?? .production
    }
}
