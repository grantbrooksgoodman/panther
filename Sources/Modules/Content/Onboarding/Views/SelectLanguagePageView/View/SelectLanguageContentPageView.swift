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

/* Proprietary */
import AppSubsystem
import ComponentKit

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

            VStack {
                Components.text(
                    viewModel.strings.value(for: .instructionLabelText),
                    font: .systemSemibold,
                    foregroundColor: Colors.instructionLabelForeground
                )
                .padding(.vertical, Floats.instructionLabelVerticalPadding)

                ThemedView(redrawsOnAppearanceChange: true) {
                    Picker("", selection: selectedLanguageBinding) {
                        ForEach(viewModel.languages, id: \.self) {
                            Components.text($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .padding(.horizontal, Floats.pickerHorizontalPadding)
                }

                Components.button(
                    viewModel.strings.value(for: .continueButtonText),
                    font: .systemSemibold
                ) {
                    viewModel.send(.continueButtonTapped)
                }
                .padding(.top, Floats.continueButtonTopPadding)

                Components.button(
                    viewModel.strings.value(for: .backButtonText),
                    font: .system(scale: .custom(Floats.backButtonLabelFontSize))
                ) {
                    viewModel.send(.backButtonTapped)
                }
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
