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

public extension NavigationBarAppearance {
    static var appDefault: NavigationBarAppearance {
        guard Application.isInPrevaricationMode else {
            return .default(scrollEdgeConfig: .init(
                titleColor: .navigationBarTitle,
                backgroundColor: (ThemeService.isDarkModeActive ? UIColor.black : .white).withAlphaComponent(0.98),
                barButtonItemColor: .accent,
                showsDivider: false
            ))
        }

        return .custom(.init(
            titleColor: .navigationBarTitle,
            backgroundColor: .navigationBarBackground,
            barButtonItemColor: .navigationBarTitle,
            showsDivider: true
        ))
    }
}
