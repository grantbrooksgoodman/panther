//
//  ThemeService+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension ThemeService {
    static var isDefaultThemeApplied: Bool { currentTheme == AppTheme.default.theme }
}
