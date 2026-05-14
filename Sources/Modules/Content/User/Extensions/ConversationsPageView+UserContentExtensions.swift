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

        for item in NavigationBar.ItemPlacement.allCases {
            NavigationBar.setItemGlassTint(
                .accent,
                for: item,
                delay: .milliseconds(10)
            )
        }
    }
}
