//
//  Locale+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public extension Locale {
    static var systemLanguageID: String {
        @Dependency(\.mainBundle) var mainBundle: Bundle
        @Dependency(\.currentLocale) var currentLocale: Locale

        let bundleLanguage = mainBundle.preferredLocalizations.first
        let localeLanguage = Locale.preferredLanguages.first
        let currentLocaleLanguage = currentLocale.language.languageCode?.identifier

        let languageCode = bundleLanguage ?? localeLanguage ?? currentLocaleLanguage
        return languageCode ?? "en-US"
    }
}
