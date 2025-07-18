//
//  ChangeLanguagePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/07/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct ChangeLanguagePageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChangeLanguagePageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<ChangeLanguagePageReducer>

    // MARK: - Bindings

    private var selectedLanguageNameBinding: Binding<String> {
        viewModel.binding(
            for: \.selectedLanguageName,
            sendAction: { .selectedLanguageNameChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChangeLanguagePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        StatefulView(
            viewModel.binding(for: \.viewState),
            progressPageViewBackgroundColor: .groupedContentBackground
        ) {
            ThemedView {
                VStack {
                    InstructionView(viewModel.instructionViewStrings)

                    VStack {
                        Picker("", selection: selectedLanguageNameBinding) {
                            ForEach(viewModel.languages, id: \.self) {
                                Components.text($0)
                            }
                            .redrawsOnTraitCollectionChange()
                        }
                        .pickerStyle(.wheel)
                        .padding(.horizontal, Floats.pickerHorizontalPadding)

                        Components.capsuleButton(
                            viewModel.strings.value(for: .confirmButtonText),
                            font: .systemSemibold
                        ) {
                            viewModel.send(.confirmButtonTapped)
                        }
                        .disabled(!viewModel.isConfirmButtonEnabled)
                    }
                    .padding(.top, Floats.innerVStackTopPadding)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.groupedContentBackground)
                .if(UIApplication.v26FeaturesEnabled) {
                    $0.navigationTitle(viewModel.strings.value(for: .navigationTitle))
                }
            }
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
        .onDisappear {
            viewModel.send(.viewDisappeared)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ChangeLanguagePageViewStringKey) -> String {
        (first(where: { $0.key == .changeLanguagePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
