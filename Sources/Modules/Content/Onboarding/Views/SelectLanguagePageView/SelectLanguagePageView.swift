//
//  SelectLanguagePageView.swift
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

struct SelectLanguagePageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.SelectLanguagePageView
    private typealias Floats = AppConstants.CGFloats.SelectLanguagePageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<SelectLanguagePageReducer>

    // MARK: - Bindings

    private var selectedLanguageNameBinding: Binding<String> {
        viewModel.binding(
            for: \.selectedLanguageName,
            sendAction: { .selectedLanguageNameChanged($0) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<SelectLanguagePageReducer>) {
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

                    Picker("", selection: selectedLanguageNameBinding) {
                        ForEach(viewModel.languages, id: \.self) {
                            Components.text($0)
                        }
                        .redrawsOnTraitCollectionChange()
                    }
                    .pickerStyle(.wheel)
                    .padding(.horizontal, Floats.pickerHorizontalPadding)

                    Components.capsuleButton(
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
                .padding(.bottom, Floats.innerVStackBottomPadding)

                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.SelectLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .selectLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
