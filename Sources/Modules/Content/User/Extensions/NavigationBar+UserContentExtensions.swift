//
//  NavigationBar+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/06/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

extension NavigationBar {
    static var height: CGFloat {
        @Dependency(\.uiApplication.presentedViewControllers) var viewControllers: [UIViewController]
        return viewControllers
            .compactMap { $0 as? UINavigationController }
            .first?
            .navigationBar
            .frame
            .height ?? 54
    }
}
