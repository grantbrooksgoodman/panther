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

/* 3rd-party */
import Redux

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
                Text(viewModel.strings.value(for: .instructionLabelText))
                    .bold()
                    .foregroundStyle(Colors.instructionLabelForeground)
                    .font(.system(size: Floats.instructionLabelFontSize))
                    .padding(.vertical, Floats.instructionLabelVerticalPadding)

                GenericTextField(
                    verificationCodeBinding,
                    keyboardType: .numberPad,
                    placeholderText: (Strings.textFieldPlaceholder, nil)
                )
                .padding(.horizontal, Floats.textFieldHorizontalPadding)
                .padding(.vertical, Floats.textFieldVerticalPadding)

                Button {
                    viewModel.send(.continueButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .continueButtonText))
                        .bold()
                }
                .accentColor(Colors.continueButtonAccent)
                .disabled(!viewModel.isContinueButtonEnabled)
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
