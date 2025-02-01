//
//  PenPalsPermissionContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct PenPalsPermissionContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.PenPalsPermissionPageView
    private typealias Floats = AppConstants.CGFloats.PenPalsPermissionPageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<PenPalsPermissionPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<PenPalsPermissionPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            VStack {
                Components.text(
                    viewModel.strings.value(for: .titleLabelText),
                    font: .systemBold(scale: .custom(Floats.titleLabelFontScale))
                )
                .padding(.bottom, Floats.titleLabelBottomPadding)
                .padding(.top, Floats.titleLabelTopPadding)

                SquareIconView(.penPalsIcon(includesShadow: true))

                ScrollView {
                    Components.text(
                        viewModel.strings.value(for: .subtitleLabelText),
                        font: .system,
                        foregroundColor: .subtitleText
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Floats.subtitleLabelHorizontalPadding)
                    .padding(.top, Floats.subtitleLabelTopPadding)
                }
                .scrollBounceBehavior(
                    .basedOnSize,
                    axes: [.vertical]
                )

                Spacer()

                Button {
                    viewModel.send(.enableButtonTapped)
                } label: {
                    Rectangle()
                        .frame(height: Floats.enableButtonLabelFrameHeight)
                        .frame(
                            minWidth: Floats.enableButtonLabelFrameMinWidth,
                            maxWidth: .infinity
                        )
                        .foregroundStyle(Color.accent)
                        .cornerRadius(Floats.enableButtonLabelCornerRadius)
                        .shadow(
                            color: Colors.enableButtonLabelShadow.opacity(Floats.enableButtonLabelShadowColorOpacity),
                            radius: Floats.enableButtonLabelShadowRadius,
                            x: 0,
                            y: Floats.enableButtonLabelShadowYOffset
                        )
                        .overlay {
                            Components.text(
                                viewModel.strings.value(for: .enableButtonText),
                                font: .systemSemibold,
                                foregroundColor: Colors.enableButtonLabelOverlayTextForeground
                            )
                        }
                        .padding(.horizontal, Floats.enableButtonLabelHorizontalPadding)
                }
                .padding(.bottom, Floats.enableButtonBottomPadding)

                Components.button(viewModel.strings.value(for: .dismissButtonText)) {
                    viewModel.send(.dismissButtonTapped)
                }
                .padding(.bottom, Floats.dismissButtonBottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.PenPalsPermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .penPalsPermissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
