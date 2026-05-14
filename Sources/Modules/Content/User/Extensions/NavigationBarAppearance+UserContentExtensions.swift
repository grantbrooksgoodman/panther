//
//  NavigationBarAppearance+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

@MainActor
extension NavigationBarAppearance {
    static var appDefault: NavigationBarAppearance {
        if Application.isInPrevaricationMode {
            .custom(.init(
                titleColor: .navigationBarTitle,
                backgroundColor: .navigationBarBackground,
                barButtonItemColor: .navigationBarTitle,
                showsDivider: true
            ))
        } else if UIApplication.isFullyV26Compatible {
            .default(scrollEdgeConfig: nil)
        } else {
            .default(scrollEdgeConfig: .init(
                titleColor: .navigationBarTitle,
                backgroundColor: (ThemeService.isDarkModeActive ? UIColor.black : .white).withAlphaComponent(0.98),
                barButtonItemColor: .accent,
                showsDivider: false
            ))
        }
    }

    static var chatPageView: NavigationBarAppearance {
        guard !Application.isInPrevaricationMode,
              UIApplication.isFullyV26Compatible else { return .appDefault }

        return .custom(
            .init(
                titleColor: .navigationBarTitle,
                backgroundColor: .navigationBarBackground.withAlphaComponent(0.75),
                barButtonItemColor: .accent,
                showsDivider: false
            ),
            scrollEdgeConfig: .v26ScrollEdgeConfig
        )
    }

    static var conversationsPageView: NavigationBarAppearance {
        guard Application.isInPrevaricationMode,
              UIApplication.isFullyV26Compatible else { return .appDefault }

        let defaultConfiguration: NavigationBarConfiguration = .init(
            titleColor: .navigationBarTitle,
            backgroundColor: .navigationBarBackground,
            barButtonItemColor: .navigationBarTitle,
            showsDivider: true
        )

        let scrollEdgeConfig: NavigationBarConfiguration = .init(
            titleColor: .accent,
            backgroundColor: .clear,
            barButtonItemColor: .black,
            showsDivider: false
        )

        return .custom(
            defaultConfiguration,
            scrollEdgeConfig: scrollEdgeConfig
        )
    }

    static var newChatPageView: NavigationBarAppearance {
        guard !Application.isInPrevaricationMode,
              UIApplication.isFullyV26Compatible else { return .appDefault }

        return .custom(
            .v26ScrollEdgeConfig,
            scrollEdgeConfig: .v26ScrollEdgeConfig
        )
    }
}

@MainActor
private extension NavigationBarConfiguration {
    static var v26ScrollEdgeConfig: NavigationBarConfiguration {
        .init(
            titleColor: .navigationBarTitle,
            backgroundColor: .clear,
            barButtonItemColor: .accent,
            showsDivider: false
        )
    }
}
