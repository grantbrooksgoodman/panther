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

    public let layout: RecipientBarLayoutService
    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
        layout = .init(viewController)
    }

    // MARK: - Methods

    public func onLayoutSubviews() {
        layout.textField?.becomeFirstResponder()
    }
}
