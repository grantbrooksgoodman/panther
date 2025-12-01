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

final class RecipientBar: UIView {
    // MARK: - Properties

    private let service: RecipientBarService

    private var didRunLayoutSubviewsEffect = false

    // MARK: - Init

    init(service: RecipientBarService) {
        self.service = service
        super.init(frame: service.layout.viewFrame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout Subviews

    override func layoutSubviews() {
        service.layout.layoutSubviews()

        guard !didRunLayoutSubviewsEffect else { return }
        service.onLayoutSubviews()
        didRunLayoutSubviewsEffect = true
    }
}
