//
//  AuthCodePageView.swift
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

struct AuthCodePageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AuthCodePageView
    private typealias Floats = AppConstants.CGFloats.AuthCodePageView
    private typealias Strings = AppConstants.Strings.AuthCodePageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<AuthCodePageReducer>

    // MARK: - Bindings

    private var verificationCodeBinding: Binding<String> {
        viewModel.binding(
            for: \.verificationCode,
            sendAction: { .verificationCodeChanged($0) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<AuthCodePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        StatefulView(viewModel.binding(for: \.viewState)) {
            VStack {
                InstructionView(viewModel.instructionViewStrings)

                Spacer()

                VStack {
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

                    Components.capsuleButton(
                        viewModel.strings.value(for: .continueButtonText),
                        font: .systemSemibold,
                        foregroundColor: viewModel.isContinueButtonEnabled ? .background : .disabled
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
                .padding(.bottom, Floats.innerVStackBottomPadding)

                Spacer()
            }
            .contentShape(Rectangle())
            .onSwipe(.down) {
                viewModel.send(.didSwipeDown)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.AuthCodePageViewStringKey) -> String {
        (first(where: { $0.key == .authCodePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
