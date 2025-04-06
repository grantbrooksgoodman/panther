//
//  NewChatPageView+HeaderItems.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 20/11/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public extension NewChatPageView {
    var headerCenterItem: HeaderView.CenterItemType {
        .text(
            .init(
                viewModel.navigationTitle,
                foregroundColor: .navigationBarTitle
            )
        )
    }

    var headerLeftItem: HeaderView.PeripheralButtonType {
        typealias Floats = AppConstants.CGFloats.NewChatPageView
        return .image(
            .init(
                image: .init(
                    image: SquareIconView.image(
                        .penPalsIcon(
                            backgroundColor: viewModel.penPalsToolbarButtonBackgroundColor
                        )
                    ).swiftUIImage ?? .missing,
                    size: .init(
                        width: Floats.penPalsToolbarButtonFrameWidth,
                        height: Floats.penPalsToolbarButtonFrameHeight
                    )
                )
            ) {
                viewModel.send(.penPalsToolbarButtonTapped)
            }
        )
    }

    var headerRightItem: HeaderView.PeripheralButtonType {
        .text(
            .init(
                text: .init(
                    viewModel.doneToolbarButtonText,
                    font: doneToolbarButtonFont,
                    foregroundColor: doneToolbarButtonForegroundColor
                ),
                isEnabled: viewModel.isDoneToolbarButtonEnabled
            ) {
                viewModel.send(.doneToolbarButtonTapped)
            }
        )
    }

    private var doneToolbarButtonFont: Font {
        ComponentKit.Font(
            .system(
                style: viewModel.shouldUseBoldDoneToolbarButton ? .semibold() : .regular()
            ),
            scale: .medium
        ).model
    }

    private var doneToolbarButtonForegroundColor: Color {
        guard !Application.isInPrevaricationMode else { return .navigationBarTitle }
        return viewModel.isDoneToolbarButtonEnabled ? .accent : .disabled
    }
}
