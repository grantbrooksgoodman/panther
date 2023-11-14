//
//  Observables.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import Redux

public enum ObservableKey: String {
    case breadcrumbsDidCapture
    case isDeveloperModeEnabled
    case themedViewAppearanceChanged
}

/// For sending and accessing observed values between scopes.
public enum Observables {
    public static let breadcrumbsDidCapture: Observable<Nil> = .init(key: .breadcrumbsDidCapture)
    public static let isDeveloperModeEnabled: Observable<Bool> = .init(.isDeveloperModeEnabled, false)
    public static let themedViewAppearanceChanged: Observable<Nil> = .init(key: .themedViewAppearanceChanged)
}
