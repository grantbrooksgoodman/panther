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

/// The service that manages the recipient bar.
///
/// Use ``RecipientBarService`` to drive the bar for choosing recipients when composing a new
/// conversation. The service groups the specialized services that build the bar's subviews,
/// reconfigure them as recipients change, manage the selected-contact views, present the contact
/// suggestions table, and handle the user's actions.
@MainActor
struct RecipientBarService {
    // MARK: - Dependencies

    @Dependency(\.uiApplication.keyViewController?.leafViewController) private var leafViewController: UIViewController?

    // MARK: - Properties

    /// The service that handles the recipient bar's user actions.
    let actionHandler: RecipientBarActionHandlerService

    /// The service that reconfigures the recipient bar and its message list as recipients change.
    let config: RecipientBarConfigService

    /// The service that manages the recipient bar's selected-contact views.
    let contactSelectionUI: RecipientBarContactSelectionUIService

    /// The service that builds and lays out the recipient bar's subviews.
    let layout: RecipientBarLayoutService

    /// The service that manages the recipient bar's contact suggestions table.
    let tableView: RecipientBarTableViewService

    private let viewController: ChatPageViewController

    // MARK: - Init

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        config = .init(viewController)
        contactSelectionUI = .init(viewController)
        layout = .init(viewController)
        tableView = .init(viewController)
    }

    // MARK: - On Layout Subviews

    /// Reloads the contact suggestions table and makes the recipient bar's text field the first
    /// responder when the chat page is frontmost.
    func onLayoutSubviews() {
        defer { tableView.reloadData() }
        if let leafViewController {
            guard leafViewController.descriptor == AppConstants.Strings.ChatPageViewService.leafViewControllerID else { return }
        }

        layout.textField?.becomeFirstResponder()
    }
}
