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

public struct RecipientBarService {
    // MARK: - Dependencies

    @Dependency(\.uiApplication.keyViewController?.frontmostViewController) private var frontmostViewController: UIViewController?

    // MARK: - Properties

    public let actionHandler: RecipientBarActionHandlerService
    public let config: RecipientBarConfigService
    public let contactSelectionUI: RecipientBarContactSelectionUIService
    public let layout: RecipientBarLayoutService
    public let tableView: RecipientBarTableViewService

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        config = .init(viewController)
        contactSelectionUI = .init(viewController)
        layout = .init(viewController)
        tableView = .init(viewController)
    }

    // MARK: - On Layout Subviews

    public func onLayoutSubviews() {
        defer { tableView.reloadData() }
        if let frontmostViewController {
            guard String(type(of: frontmostViewController)) == AppConstants.Strings.ChatPageViewService.frontmostViewControllerID else { return }
        }

        layout.textField?.becomeFirstResponder()
    }
}
