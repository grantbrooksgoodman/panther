//
//  BuildConfig.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum BuildConfig {
    // MARK: - Flags

    public static let loggingEnabled = true
    public static let timebombActive = true

    // MARK: - Names

    public static let codeName = "Panther"
    public static let finalName = "Hello"

    // MARK: - Versioning

    public static let appStoreReleaseVersion = 0
    public static let dmyFirstCompileDateString = "11112023"
    public static let stage: Build.Stage = .alpha

    // MARK: - Other

    public static let languageCode = Locale.systemLanguageCode
    public static let loggerDomainSubscriptions: [LoggerDomain] = [
        .contacts,
        .conversation,
        .general,
        .hostedTranslation,
        .notifications,
        .queue,
        .user,
    ]
    public static let networkEnvironment: NetworkEnvironment = .development
}
