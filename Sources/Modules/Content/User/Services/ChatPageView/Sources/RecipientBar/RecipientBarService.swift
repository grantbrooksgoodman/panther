//
//  RecipientBarService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 12/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

struct RecipientBarService {
    // MARK: - Dependencies

    @Dependency(\.uiApplication.keyViewController?.leafViewController) private var leafViewController: UIViewController?

    // MARK: - Properties

    let actionHandler: RecipientBarActionHandlerService
    let config: RecipientBarConfigService
    let contactSelectionUI: RecipientBarContactSelectionUIService
    let layout: RecipientBarLayoutService
    let tableView: RecipientBarTableViewService

    private let viewController: ChatPageViewController

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        config = .init(viewController)
        contactSelectionUI = .init(viewController)
        layout = .init(viewController)
        tableView = .init(viewController)
    }

    // MARK: - On Layout Subviews

    func onLayoutSubviews() {
        defer { tableView.reloadData() }
        if let leafViewController {
            guard leafViewController.descriptor == AppConstants.Strings.ChatPageViewService.leafViewControllerID else { return }
        }

        layout.textField?.becomeFirstResponder()
    }
}
