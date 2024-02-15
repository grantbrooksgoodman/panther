//
//  RecipientBarTextField.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public final class RecipientBarTextField: UITextField {
    // MARK: - Properties

    private var _onSuperfluousBackspace: (() -> Void)?

    // MARK: - Init

    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Delete Backward

    override public func deleteBackward() {
        if (text ?? "").isBlank { _onSuperfluousBackspace?() }
        super.deleteBackward()
    }

    // MARK: - On Superfluous Backspace

    public func onSuperfluousBackspace(_ onSuperfluousBackspace: @escaping () -> Void) {
        _onSuperfluousBackspace = onSuperfluousBackspace
    }
}
