//
//  InstructionViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The display strings for an ``InstructionView``.
///
/// Use ``InstructionViewStrings`` to supply the title and subtitle text an ``InstructionView``
/// displays. Reducers typically store a value of this type in their state – initialized to
/// ``empty`` – and replace it with localized text once translation completes.
struct InstructionViewStrings: Equatable {
    // MARK: - Properties

    /// A strings value whose title and subtitle are both empty.
    ///
    /// Use `empty` as a placeholder before localized text becomes available, such as when
    /// initializing reducer state.
    static let empty: InstructionViewStrings = .init(titleLabelText: "", subtitleLabelText: "")

    /// The text an ``InstructionView`` displays as its subtitle.
    let subtitleLabelText: String

    /// The text an ``InstructionView`` displays as its title.
    let titleLabelText: String

    // MARK: - Init

    /// Creates a strings value with the given title and subtitle text.
    ///
    /// - Parameters:
    ///   - titleLabelText: The text to display as the title.
    ///   - subtitleLabelText: The text to display as the subtitle.
    init(
        titleLabelText: String,
        subtitleLabelText: String
    ) {
        self.titleLabelText = titleLabelText
        self.subtitleLabelText = subtitleLabelText
    }
}
