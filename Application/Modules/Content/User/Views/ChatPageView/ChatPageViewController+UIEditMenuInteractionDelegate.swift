//
//  ChatPageViewController+UIEditMenuInteractionDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 07/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import Redux

extension ChatPageViewController: UIEditMenuInteractionDelegate {
    // MARK: - Menu for Configuration

    public func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        guard let indexPathSection = configuration.identifier as? Int else { return nil }
        return menuService?.menuForMessage(at: indexPathSection)
    }

    // MARK: - Will Dismiss Menu for Configuration

    public func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        willDismissMenuFor configuration: UIEditMenuConfiguration,
        animator: UIEditMenuInteractionAnimating
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        guard let indexPathSection = configuration.identifier as? Int else { return }
        menuService?.setIsShowingMenu(false, at: indexPathSection)
    }

    // MARK: - Will Present Menu for Configuration

    public func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        willPresentMenuFor configuration: UIEditMenuConfiguration,
        animator: UIEditMenuInteractionAnimating
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        guard let indexPathSection = configuration.identifier as? Int else { return }
        menuService?.setIsShowingMenu(true, at: indexPathSection)
    }
}
