//
//  SignInContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import ComponentKit
import CoreArchitecture

public struct SignInContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SignInPageView
    private typealias Floats = AppConstants.CGFloats.SignInPageView
    private typealias Strings = AppConstants.Strings.SignInPageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<SignInPageReducer>

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

    private var verificationCodeBinding: Binding<String> {
        viewModel.binding(
            for: \.verificationCode,
            sendAction: { .verificationCodeChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<SignInPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            VStack {
                Image(.hello)
                    .resizable()
                    .renderingMode(ThemeService.isDarkModeActive ? .template : .original)
                    .foregroundColor(ThemeService.isDarkModeActive ? Colors.imageDarkForeground : .none)
                    .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                    .padding(.bottom, Floats.imageBottomPadding)

                Components.text(viewModel.instructionLabelText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Floats.instructionLabelHorizontalPadding)
                    .padding(.vertical, Floats.instructionLabelVerticalPadding)

                if viewModel.configuration == .phoneNumber {
                    HStack(alignment: .center) {
                        RegionMenu(selectedRegionCodeBinding)
                            .padding(.leading, Floats.regionMenuLeadingPadding)
                            .padding(.trailing, Floats.regionMenuTrailingPadding)
                            .id(viewModel.regionMenuViewID)

                        PhoneNumberTextField(
                            phoneNumberStringBinding,
                            regionCode: selectedRegionCodeBinding
                        )
                        .padding(.trailing, Floats.phoneNumberTextFieldTrailingPadding)
                        .padding(.vertical, Floats.phoneNumberTextFieldVerticalPadding)
                    }
                } else {
                    GenericTextField(
                        verificationCodeBinding,
                        keyboardType: .numberPad,
                        placeholderText: (Strings.textFieldPlaceholder, nil)
                    )
                    .padding(.horizontal, Floats.textFieldHorizontalPadding)
                    .padding(.vertical, Floats.textFieldVerticalPadding)
                }

                Components.button(
                    viewModel.continueButtonText,
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .interactivePopGestureRecognizerDisabled(viewModel.configuration == .verificationCode)
            .contentShape(Rectangle())
            .onSwipe(.down) {
                viewModel.send(.didSwipeDown)
            }
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SignInPageViewStringKey) -> String {
        (first(where: { $0.key == .signInPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
