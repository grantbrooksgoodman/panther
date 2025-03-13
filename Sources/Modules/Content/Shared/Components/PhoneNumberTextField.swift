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

public struct PhoneNumberTextField: View {
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

    public init(_ text: Binding<String>, regionCode: Binding<String>) {
        _text = text
        _regionCode = regionCode
    }

    // MARK: - View

    public var body: some View {
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
