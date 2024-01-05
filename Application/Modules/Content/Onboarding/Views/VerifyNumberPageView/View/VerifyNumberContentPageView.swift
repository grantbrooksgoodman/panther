//
//  VerifyNumberContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct VerifyNumberContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.VerifyNumberPageView
    private typealias Floats = AppConstants.CGFloats.VerifyNumberPageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<VerifyNumberPageReducer>

    // MARK: - Bindings

    private var phoneNumberStringBinding: Binding<String> {
        viewModel.binding(
            for: \.phoneNumberString,
            sendAction: { .phoneNumberStringChanged($0) }
        )
    }

    private var selectedRegionCodeBinding: Binding<String> {
        viewModel.binding(
            for: \.selectedRegionCode,
            sendAction: { .selectedRegionCodeChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<VerifyNumberPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        VStack {
            InstructionView(viewModel.instructionViewStrings)

            Spacer()

            VStack(alignment: .center) {
                Text(viewModel.strings.value(for: .instructionLabelText))
                    .bold()
                    .foregroundColor(Colors.instructionLabelForeground)
                    .font(.system(size: Floats.instructionLabelFontSize))
                    .padding(.vertical, Floats.instructionLabelVerticalPadding)

                HStack(alignment: .center) {
                    RegionMenu(selectedRegionCodeBinding)
                        .padding(.leading, Floats.regionMenuLeadingPadding)
                        .padding(.trailing, Floats.regionMenuTrailingPadding)

                    PhoneNumberTextField(
                        phoneNumberStringBinding,
                        regionCode: viewModel.selectedRegionCode
                    )
                    .padding(.vertical, Floats.phoneNumberTextFieldVerticalPadding)
                    .padding(.trailing, Floats.phoneNumberTextFieldTrailingPadding)
                }

                Button {
                    viewModel.send(.continueButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .continueButtonText))
                        .bold()
                }
                .padding(.top, Floats.continueButtonTopPadding)
                .accentColor(Colors.continueButtonAccent)
                .disabled(!viewModel.isContinueButtonEnabled)

                Button {
                    viewModel.send(.backButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .backButtonText))
                }
                .padding(.top, Floats.backButtonTopPadding)
                .foregroundColor(Colors.backButtonForeground)
                .font(.system(size: Floats.backButtonFontSize))
            }
            .padding(.bottom, Floats.bottomPadding)

            Spacer()
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.VerifyNumberPageViewStringKey) -> String {
        (first(where: { $0.key == .verifyNumberPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
