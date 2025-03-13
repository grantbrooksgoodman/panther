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
        guard !Application.isInPrevaricationMode,
              ThemeService.isAppDefaultThemeApplied else { return .navigationBarTitle }
        return viewModel.isDoneToolbarButtonEnabled ? .accent : .disabled
    }
}
