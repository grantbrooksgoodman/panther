//
//  WelcomeContentPageView.swift
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

public struct WelcomeContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.WelcomePageView
    private typealias Floats = AppConstants.CGFloats.WelcomePageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<WelcomePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<WelcomePageReducer>) {
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

                Components.text(viewModel.strings.value(for: .instructionLabelText))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Floats.instructionLabelHorizontalPadding)
                    .padding(.vertical, Floats.instructionLabelVerticalPadding)

                Components.button(
                    viewModel.strings.value(for: .continueButtonText),
                    font: .systemSemibold
                ) {
                    viewModel.send(.continueButtonTapped)
                }
                .padding(.vertical, Floats.continueButtonVerticalPadding)

                Components.button(viewModel.strings.value(for: .signInButtonText)) {
                    viewModel.send(.signInButtonTapped)
                }
                .padding(.vertical, Floats.signInButtonVerticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.WelcomePageViewStringKey) -> String {
        (first(where: { $0.key == .welcomePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
