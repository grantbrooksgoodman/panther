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

/* 3rd-party */
import Redux

public final class RecipientBarService {
    // MARK: - Properties

    public let actionHandler: RecipientBarActionHandlerService
    public let layout: RecipientBarLayoutService
    public let tableView: RecipientBarTableViewService

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        actionHandler = .init(viewController)
        layout = .init(viewController)
        tableView = .init(viewController)
    }

    // MARK: - Methods

    public func onLayoutSubviews() {
        layout.textField?.becomeFirstResponder()
        tableView.reloadData()
    }
}
