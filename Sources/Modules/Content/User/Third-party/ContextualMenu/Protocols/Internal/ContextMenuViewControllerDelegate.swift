//
//  ContextMenuViewControllerDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

protocol ContextMenuViewControllerDelegate: AnyObject {
    func dismissContextMenuViewController(
        _ contextMenuViewController: ContextMenuViewController,
        interaction: ContextMenuInteractor.Interaction,
        uponTapping menuElement: MenuElement?
    )
}
