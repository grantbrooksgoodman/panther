//
//  GenericTextField.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

/// A single-line text field with an underline divider and configurable input behavior.
///
/// Use ``GenericTextField`` as the base text entry control for the app's pages. The field binds
/// to the given text, displays placeholder text while empty, and draws a divider beneath its
/// content. Configure keyboard, autocapitalization, autocorrection, alignment, and colors through
/// the initializer; every parameter but the text binding and placeholder has a default.
struct GenericTextField: View {
    // MARK: - Constants Accessors

    /// A convenience alias for the field's layout constants.
    typealias Floats = AppConstants.CGFloats.GenericTextField

    // MARK: - Properties

    private let alignment: TextAlignment
    private let autocapitalization: TextInputAutocapitalization?
    private let dividerXOffset: CGFloat
    private let dividerYOffset: CGFloat
    private let isAutocorrectEnabled: Bool
    private let isThemed: Bool
    private let keyboardType: UIKeyboardType
    private let placeholderText: (string: String, color: Color)
    private let submitLabel: SubmitLabel
    private let textColor: Color

    @Binding private var text: String

    // MARK: - Init

    /// Creates a text field with the given text binding and configuration.
    ///
    /// - Parameters:
    ///   - text: A binding to the text the field displays and edits.
    ///   - alignment: The alignment of the field's text.
    ///   - autocapitalization: The autocapitalization behavior to apply, or `nil` for the system
    ///     default.
    ///   - isAutocorrectEnabled: A Boolean value that determines whether autocorrection is
    ///     enabled.
    ///   - isThemed: A Boolean value that determines whether the field is wrapped in a themed
    ///     container.
    ///   - keyboardType: The keyboard type to display during editing.
    ///   - placeholderText: The placeholder string to display while the field is empty, and its
    ///     color. Pass `nil` for the color to use gray.
    ///   - submitLabel: The label of the keyboard's submit button.
    ///   - textColor: The color of the field's text.
    ///   - dividerXOffset: The horizontal offset of the field's divider.
    ///   - dividerYOffset: The vertical offset of the field's divider.
    init(
        _ text: Binding<String>,
        alignment: TextAlignment = .center,
        autocapitalization: TextInputAutocapitalization? = nil,
        isAutocorrectEnabled: Bool = false,
        isThemed: Bool = false,
        keyboardType: UIKeyboardType = .default,
        placeholderText: (string: String, color: Color?),
        submitLabel: SubmitLabel = .done,
        textColor: Color = .titleText,
        dividerXOffset: CGFloat = Floats.defaultDividerXOffset,
        dividerYOffset: CGFloat = Floats.defaultDividerYOffset
    ) {
        _text = text
        self.alignment = alignment
        self.autocapitalization = autocapitalization
        self.isAutocorrectEnabled = isAutocorrectEnabled
        self.isThemed = isThemed
        self.keyboardType = keyboardType
        self.placeholderText = (placeholderText.string, placeholderText.color ?? .gray)
        self.submitLabel = submitLabel
        self.textColor = textColor
        self.dividerXOffset = dividerXOffset
        self.dividerYOffset = dividerYOffset
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        let textField = TextField(
            "",
            text: $text,
            prompt: Text(placeholderText.string)
                .foregroundColor(placeholderText.color)
        )
        .autocorrectionDisabled(!isAutocorrectEnabled)
        .dynamicTypeSize(.large)
        .textInputAutocapitalization(autocapitalization)
        .foregroundStyle(textColor)
        .keyboardType(keyboardType)
        .multilineTextAlignment(alignment)
        .submitLabel(submitLabel)
        .overlay(
            VStack {
                Divider()
                    .offset(
                        x: dividerXOffset,
                        y: dividerYOffset
                    )
            }
        )

        if isThemed {
            return ThemedView { textField }.eraseToAnyView()
        }

        return textField.eraseToAnyView()
    }
}
