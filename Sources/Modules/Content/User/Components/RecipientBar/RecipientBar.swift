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

/// The bar for choosing recipients when composing a new conversation.
///
/// ``RecipientBar`` hosts a text field for entering a recipient's name or phone number and a
/// table of matching contacts. The bar delegates its behavior to `RecipientBarService`; this
/// class provides the view itself and its data source and delegate conformances.
final class RecipientBar: UIView {
    // MARK: - Properties

    private let service: RecipientBarService

    private var didRunLayoutSubviewsEffect = false

    // MARK: - Init

    /// Creates a recipient bar driven by the given service.
    ///
    /// The bar's frame is taken from the service's layout.
    ///
    /// - Parameter service: The service that drives the bar.
    init(service: RecipientBarService) {
        self.service = service
        super.init(frame: service.layout.viewFrame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout Subviews

    /// Lays out the bar's subviews through the service's layout, running the service's
    /// one-time layout effect on the first pass.
    override func layoutSubviews() {
        service.layout.layoutSubviews()

        guard !didRunLayoutSubviewsEffect else { return }
        service.onLayoutSubviews()
        didRunLayoutSubviewsEffect = true
    }
}
