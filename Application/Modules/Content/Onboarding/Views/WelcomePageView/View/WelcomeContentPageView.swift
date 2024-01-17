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

/* 3rd-party */
import Redux

public struct WelcomeContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.WelcomePageView
    private typealias Floats = AppConstants.CGFloats.WelcomePageView
    private typealias Strings = AppConstants.Strings.WelcomePageView

    // MARK: - Properties

    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @ObservedObject private var viewModel: ViewModel<WelcomePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<WelcomePageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        VStack {
            Image(uiImage: UIImage(named: Strings.imageName)!)
                .resizable()
                .renderingMode(colorScheme == .dark ? .template : .original)
                .foregroundColor(colorScheme == .dark ? Colors.imageDarkForeground : .none)
                .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                .padding(.bottom, Floats.imageBottomPadding)

            Text(viewModel.strings.value(for: .instructionLabelText))
                .padding(.vertical, Floats.instructionLabelVerticalPadding)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Floats.instructionLabelHorizontalPadding)

            Button {
                viewModel.send(.continueButtonTapped)
            } label: {
                Text(viewModel.strings.value(for: .continueButtonText))
                    .bold()
            }
            .foregroundStyle(Colors.continueButtonForeground)
            .padding(.vertical, Floats.continueButtonVerticalPadding)

            Button {
                viewModel.send(.signInButtonTapped)
            } label: {
                Text(viewModel.strings.value(for: .signInButtonText))
            }
            .foregroundStyle(Colors.signInButtonForeground)
            .padding(.vertical, Floats.signInButtonVerticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.WelcomePageViewStringKey) -> String {
        (first(where: { $0.key == .welcomePageView(key) })?.value ?? key.rawValue).sanitized
    }
}
