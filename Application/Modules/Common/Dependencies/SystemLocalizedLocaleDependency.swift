//
//  SystemLocalizedLocaleDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum SystemLocalizedLocaleDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> Locale {
        .init(languageCode: .init(RuntimeStorage.languageCode))
    }
}

public extension DependencyValues {
    var systemLocalizedLocale: Locale {
        get { self[SystemLocalizedLocaleDependency.self] }
        set { self[SystemLocalizedLocaleDependency.self] = newValue }
    }
}
