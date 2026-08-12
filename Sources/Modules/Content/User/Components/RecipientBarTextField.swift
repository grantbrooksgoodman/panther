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

/// A text field that reports backspaces made while its text is empty.
///
/// Use ``RecipientBarTextField`` in the recipient bar to react when the user backspaces past
/// the entered text.
final class RecipientBarTextField: UITextField {
    // MARK: - Properties

    private var _onSuperfluousBackspace: (() -> Void)?

    // MARK: - Init

    /// Creates a recipient bar text field with the given frame.
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Delete Backward

    /// Runs the superfluous backspace handler when the text is empty, then performs the
    /// standard deletion.
    override func deleteBackward() {
        if (text ?? "").isEmpty { _onSuperfluousBackspace?() }
        super.deleteBackward()
    }

    // MARK: - On Superfluous Backspace

    /// Registers a handler to run when the user backspaces while the text field is empty.
    ///
    /// Registering a new handler replaces any existing one.
    ///
    /// - Parameter onSuperfluousBackspace: The handler to run.
    func onSuperfluousBackspace(_ onSuperfluousBackspace: @escaping () -> Void) {
        _onSuperfluousBackspace = onSuperfluousBackspace
    }
}
