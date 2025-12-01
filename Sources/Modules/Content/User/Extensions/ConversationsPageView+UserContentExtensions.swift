//
//  ConversationsPageView+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/09/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

extension ConversationsPageView {
    static func reapplyNavigationBarItemGlassTintIfNeeded() {
        guard !ThemeService.isAppDefaultThemeApplied,
              UIApplication.isGlassTintingEnabled else { return }

        NavigationBar.ItemPlacement.allCases.forEach {
            NavigationBar.setItemGlassTint(
                .accent,
                for: $0,
                delay: .milliseconds(10)
            )
        }
    }
}
