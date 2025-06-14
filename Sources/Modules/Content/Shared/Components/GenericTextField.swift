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

public struct GenericTextField: View {
    // MARK: - Constants Accessors

    public typealias Floats = AppConstants.CGFloats.GenericTextField

    // MARK: - Properties

    // Bool
    private let isAutocorrectEnabled: Bool
    private let isThemed: Bool

    // CGFloat
    private let dividerXOffset: CGFloat
    private let dividerYOffset: CGFloat

    // Other
    private let alignment: TextAlignment
    private let autocapitalization: TextInputAutocapitalization?
    private let keyboardType: UIKeyboardType
    private let placeholderText: (string: String, color: Color)
    private let submitLabel: SubmitLabel
    private let textColor: Color

    @Binding private var text: String

    // MARK: - Init

    public init(
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

    public var body: some View {
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
