//
//  ContextMenuInteractor+Extensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

extension ContextMenuInteractor: ContextMenuViewControllerDelegate {
    func dismissContextMenuViewController(
        _ contextMenuViewController: ContextMenuViewController,
        interaction: ContextMenuInteractor.Interaction,
        uponTapping menuElement: MenuElement?
    ) {
        dismissContextMenu(interaction: interaction) {
            if let menuElement {
                menuElement.handler?(menuElement)
            }
        }
    }
}

extension ContextMenuInteractor {
    class Interaction {
        // MARK: - Properties

        let gesture: UIGestureRecognizer
        let menuConfigurationProvider: MenuConfigurationProvider
        let style: ContextMenuStyle
        let targetedPreviewProvider: TargetedPreviewProvider

        private(set) var onInteractionBeganEffect: (() -> Void)?
        private(set) var onInteractionEndedEffect: (() -> Void)?

        // MARK: - Init

        deinit {
            onInteractionBeganEffect = nil
            onInteractionEndedEffect = nil
        }

        init(
            gesture: UIGestureRecognizer,
            targetedPreviewProvider: @escaping TargetedPreviewProvider,
            menuConfigurationProvider: @escaping MenuConfigurationProvider,
            style: ContextMenuStyle,
            onInteractionBegan: (() -> Void)?,
            onInteractionEnded: (() -> Void)?
        ) {
            self.gesture = gesture
            self.targetedPreviewProvider = targetedPreviewProvider
            self.menuConfigurationProvider = menuConfigurationProvider
            self.style = style

            onInteractionBeganEffect = onInteractionBegan
            onInteractionEndedEffect = onInteractionEnded
        }
    }
}
