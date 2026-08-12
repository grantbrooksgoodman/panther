//
//  PhoneNumberTextField.swift
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

/// A text field that formats an entered phone number as the user types.
///
/// Use ``PhoneNumberTextField`` to accept phone number input for a specific region. The field
/// displays an example number for the given region as its placeholder and reformats the entered
/// digits into a partially formatted national number whenever the text or region changes.
///
/// - Note: Formatting rewrites the bound text asynchronously, so the value observed immediately
///   after a change may not yet be formatted.
struct PhoneNumberTextField: View {
    // MARK: - Dependencies

    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    @Binding private var regionCode: String
    @Binding private var text: String

    // MARK: - Computed Properties

    private var partiallyFormatted: String {
        PhoneNumber(
            callingCode: services.regionDetail.callingCode(regionCode: regionCode) ?? services.phoneNumber.deviceCallingCode,
            nationalNumberString: text.digits,
            regionCode: regionCode,
            label: nil,
            internalFormattedString: nil
        ).partiallyFormatted(forRegion: regionCode)
    }

    // MARK: - Init

    /// Creates a phone number text field with the given text and region bindings.
    ///
    /// - Parameters:
    ///   - text: A binding to the phone number string the field displays and edits.
    ///   - regionCode: A binding to the code of the region used for formatting and the
    ///     placeholder.
    init(
        _ text: Binding<String>,
        regionCode: Binding<String>
    ) {
        _text = text
        _regionCode = regionCode
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        GenericTextField(
            $text,
            keyboardType: .phonePad,
            placeholderText: (services.phoneNumber.exampleNationalNumberString(for: regionCode), nil)
        )
        .onChange(of: text) { _, newValue in
            guard !newValue.isBlank else { return }
            Task { @MainActor in
                text = partiallyFormatted
            }
        }
        .onChange(of: regionCode) { _, _ in
            guard !text.isBlank else { return }
            Task { @MainActor in
                text = partiallyFormatted
            }
        }
    }
}
