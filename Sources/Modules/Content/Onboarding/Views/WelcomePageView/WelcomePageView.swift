//
//  WelcomePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct WelcomePageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.WelcomePageView
    private typealias Floats = AppConstants.CGFloats.WelcomePageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<WelcomePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<WelcomePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        StatefulView(viewModel.binding(for: \.viewState)) {
            VStack {
                Image(.hello)
                    .resizable()
                    .renderingMode(ThemeService.isDarkModeActive ? .template : .original)
                    .foregroundColor(ThemeService.isDarkModeActive ? Colors.imageDarkForeground : .none)
                    .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                    .padding(.bottom, Floats.imageBottomPadding)

                Components.text(
                    viewModel.welcomeLabelText,
                    font: .systemBold(scale: .large)
                )
                .animation(.easeIn, value: viewModel.welcomeLabelText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Floats.instructionLabelHorizontalPadding)
                .padding(.vertical, Floats.instructionLabelVerticalPadding)
                .onTapGesture {
                    viewModel.send(.welcomeLabelTapped)
                }

                Components.capsuleButton(
                    viewModel.strings.value(for: .continueButtonText),
                    font: .systemSemibold
                ) {
                    viewModel.send(.continueButtonTapped)
                }
                .padding(.vertical, Floats.continueButtonVerticalPadding)

                Components.button(
                    viewModel.strings.value(for: .signInButtonText),
                    font: .system(scale: .custom(Floats.signInButtonLabelFontSize)),
                ) {
                    viewModel.send(.signInButtonTapped)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.send(.viewAppeared)
        }
        .onFirstAppear {
            viewModel.send(.viewFirstAppeared)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.WelcomePageViewStringKey) -> String {
        (first(where: { $0.key == .welcomePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
