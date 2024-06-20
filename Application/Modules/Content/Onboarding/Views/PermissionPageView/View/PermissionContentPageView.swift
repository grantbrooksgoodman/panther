//
//  PermissionContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import ComponentKit
import CoreArchitecture

public struct PermissionContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.PermissionsView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<PermissionPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<PermissionPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        VStack {
            InstructionView(viewModel.instructionViewStrings)

            Spacer()

            VStack(alignment: .center) {
                StatusIndicatorButton(
                    viewModel.strings.value(for: .contactPermissionCapsuleButtonText),
                    action: {
                        viewModel.send(.contactPermissionCapsuleButtonTapped)
                    },
                    isCompleted: viewModel.isContactPermissionGranted
                )

                StatusIndicatorButton(
                    viewModel.strings.value(for: .notificationPermissionCapsuleButtonText),
                    action: {
                        viewModel.send(.notificationPermissionCapsuleButtonTapped)
                    },
                    isCompleted: viewModel.isNotificationPermissionGranted
                )
            }
            .padding(.bottom, Floats.buttonVStackBottomPadding)
            .padding(.top, Floats.buttonVStackTopPadding)

            Components.button(
                viewModel.strings.value(for: .finishButtonText),
                font: .systemSemibold,
                foregroundColor: viewModel.isFinishButtonEnabled ? .accent : .disabled
            ) {
                viewModel.send(.finishButtonTapped)
            }
            .disabled(!viewModel.isFinishButtonEnabled)
            .padding(.top, Floats.finishButtonTopPadding)

            Components.button(
                viewModel.strings.value(for: .backButtonText),
                font: .system(scale: .custom(Floats.backButtonLabelFontSize)),
                foregroundColor: viewModel.isBackButtonEnabled ? .accent : .disabled
            ) {
                viewModel.send(.backButtonTapped)
            }
            .disabled(!viewModel.isBackButtonEnabled)
            .padding(.top, Floats.backButtonTopPadding)

            Spacer()
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
