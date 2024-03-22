//
//  SelectLanguageContentPageView.swift
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

public struct SelectLanguageContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SelectLanguagePageView
    private typealias Floats = AppConstants.CGFloats.SelectLanguagePageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<SelectLanguagePageReducer>

    // MARK: - Bindings

    private var selectedLanguageBinding: Binding<String> {
        viewModel.binding(
            for: \.selectedLanguage,
            sendAction: { .selectedLanguageChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<SelectLanguagePageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        VStack {
            InstructionView(viewModel.instructionViewStrings)

            VStack(alignment: .center) {
                Text(viewModel.strings.value(for: .instructionLabelText))
                    .bold()
                    .foregroundStyle(Colors.instructionLabelForeground)
                    .font(.system(size: Floats.instructionLabelFontSize))
                    .padding(.vertical, Floats.instructionLabelVerticalPadding)

                Picker("", selection: selectedLanguageBinding) {
                    ForEach(viewModel.languages, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.wheel)
                .padding(.horizontal, Floats.pickerHorizontalPadding)

                Button {
                    viewModel.send(.continueButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .continueButtonText))
                        .bold()
                }
                .disabled(!viewModel.isContinueButtonEnabled)
                .foregroundStyle(Colors.continueButtonForeground)
                .padding(.top, Floats.continueButtonTopPadding)

                Button {
                    viewModel.send(.backButtonTapped)
                } label: {
                    Text(viewModel.strings.value(for: .backButtonText))
                }
                .font(.system(size: Floats.backButtonLabelFontSize))
                .foregroundStyle(Colors.backButtonForeground)
                .padding(.top, Floats.backButtonTopPadding)
            }
            .padding(.top, Floats.topPadding)

            Spacer()
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.SelectLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .selectLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
