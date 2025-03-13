//
//  AuthCodeContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct AuthCodeContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AuthCodePageView
    private typealias Floats = AppConstants.CGFloats.AuthCodePageView
    private typealias Strings = AppConstants.Strings.AuthCodePageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<AuthCodePageReducer>

    // MARK: - Bindings

    private var verificationCodeBinding: Binding<String> {
        viewModel.binding(
            for: \.verificationCode,
            sendAction: { .verificationCodeChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<AuthCodePageReducer>) {
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

                GenericTextField(
                    verificationCodeBinding,
                    keyboardType: .numberPad,
                    placeholderText: (Strings.textFieldPlaceholder, nil)
                )
                .padding(.horizontal, Floats.textFieldHorizontalPadding)
                .padding(.vertical, Floats.textFieldVerticalPadding)

                Components.button(
                    viewModel.strings.value(for: .continueButtonText),
                    font: .systemSemibold,
                    foregroundColor: viewModel.isContinueButtonEnabled ? .accent : .disabled
                ) {
                    viewModel.send(.continueButtonTapped)
                }
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
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
