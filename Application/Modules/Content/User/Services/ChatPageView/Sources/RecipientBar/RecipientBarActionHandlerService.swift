//
//  RecipientBarActionHandlerService.swift
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

public final class RecipientBarActionHandlerService {
    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Action Handlers

    @objc
    public func selectContactButtonTapped() {}

    @objc
    public func textFieldChanged(_ textField: UITextField) {
        @Dependency(\.chatPageViewService.recipientBar?.tableView) var tableViewService: RecipientBarTableViewService?
        guard let text = textField.text else { return }
        tableViewService?.setQuery(text)
    }
}
