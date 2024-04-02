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
import Redux

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
        VStack {
            Image(.hello)
                .resizable()
                .renderingMode(ThemeService.isDarkModeActive ? .template : .original)
                .foregroundColor(ThemeService.isDarkModeActive ? Colors.imageDarkForeground : .none)
                .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                .padding(.bottom, Floats.imageBottomPadding)
                .onTraitCollectionChange {
                    viewModel.send(.traitCollectionChanged)
                }

            Text(viewModel.instructionLabelText)
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

            Button {
                viewModel.send(.continueButtonTapped)
            } label: {
                Text(viewModel.continueButtonText)
                    .bold()
            }
            .disabled(!viewModel.isContinueButtonEnabled)
            .accentColor(Colors.continueButtonAccent)
            .padding(.top, Floats.continueButtonTopPadding)

            Button {
                viewModel.send(.backButtonTapped)
            } label: {
                Text(viewModel.strings.value(for: .backButtonText))
            }
            .disabled(!viewModel.isBackButtonEnabled)
            .font(.system(size: Floats.backButtonLabelFontSize))
            .foregroundStyle(Colors.backButtonForeground)
            .padding(.top, Floats.backButtonTopPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onSwipe(.down) {
            viewModel.send(.didSwipeDown)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SignInPageViewStringKey) -> String {
        (first(where: { $0.key == .signInPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
