//
//  RecipientBar.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public final class RecipientBar: UIView {
    // MARK: - Properties

    private let service: RecipientBarService

    // MARK: - Init

    public init(service: RecipientBarService) {
        self.service = service
        super.init(frame: service.layout.viewFrame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout Subviews

    override public func layoutSubviews() {
        service.layout.layoutSubviews()
        service.onLayoutSubviews()
    }
}
