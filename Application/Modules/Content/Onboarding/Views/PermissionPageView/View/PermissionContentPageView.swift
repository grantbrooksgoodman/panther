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
import Redux

public struct PermissionContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.PermissionsView
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

            Button {
                viewModel.send(.finishButtonTapped)
            } label: {
                Text(viewModel.strings.value(for: .finishButtonText))
                    .bold()
            }
            .accentColor(Colors.finishButtonAccent)
            .padding(.top, Floats.finishButtonTopPadding)
            .disabled(!viewModel.isFinishButtonEnabled)

            Button {
                viewModel.send(.backButtonTapped)
            } label: {
                Text(viewModel.strings.value(for: .backButtonText))
            }
            .disabled(!viewModel.isBackButtonEnabled)
            .font(.system(size: Floats.backButtonLabelFontSize))
            .foregroundStyle(Colors.backButtonForeground)
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
