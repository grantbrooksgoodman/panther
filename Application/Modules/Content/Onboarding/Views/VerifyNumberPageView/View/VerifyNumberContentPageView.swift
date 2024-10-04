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

/* Proprietary */
import AppSubsystem
import ComponentKit

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
                Components.text(
                    viewModel.strings.value(for: .instructionLabelText),
                    font: .systemSemibold,
                    foregroundColor: Colors.instructionLabelForeground
                )
                .padding(.vertical, Floats.instructionLabelVerticalPadding)

                HStack(alignment: .center) {
                    RegionMenu(selectedRegionCodeBinding)
                        .padding(.leading, Floats.regionMenuLeadingPadding)
                        .padding(.trailing, Floats.regionMenuTrailingPadding)
                        .id(viewModel.regionMenuViewID)

                    ThemedView {
                        PhoneNumberTextField(
                            phoneNumberStringBinding,
                            regionCode: selectedRegionCodeBinding
                        )
                        .padding(.trailing, Floats.phoneNumberTextFieldTrailingPadding)
                        .padding(.vertical, Floats.phoneNumberTextFieldVerticalPadding)
                    }
                }

                Components.button(
                    viewModel.strings.value(for: .continueButtonText),
                    font: .systemSemibold,
                    foregroundColor: viewModel.isContinueButtonEnabled ? .accent : .disabled
                ) {
                    viewModel.send(.continueButtonTapped)
                }
                .disabled(!viewModel.isContinueButtonEnabled)
                .padding(.top, Floats.continueButtonTopPadding)

                Components.button(
                    viewModel.strings.value(for: .backButtonText),
                    font: .system(scale: .custom(Floats.backButtonLabelFontSize)),
                    foregroundColor: viewModel.isBackButtonEnabled ? .accent : .disabled
                ) {
                    viewModel.send(.backButtonTapped)
                }
                .disabled(!viewModel.isBackButtonEnabled)
                .padding(.top, Floats.backButtonTopPadding)
            }
            .padding(.bottom, Floats.bottomPadding)

            Spacer()
        }
        .contentShape(Rectangle())
        .onSwipe(.down) {
            viewModel.send(.didSwipeDown)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.VerifyNumberPageViewStringKey) -> String {
        (first(where: { $0.key == .verifyNumberPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
