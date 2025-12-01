//
//  PermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct PermissionPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.PermissionsView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<PermissionPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<PermissionPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        StatefulView(viewModel.binding(for: \.viewState)) {
            VStack {
                InstructionView(viewModel.instructionViewStrings)

                Spacer()

                VStack {
                    VStack {
                        StatusIndicatorButton(
                            viewModel.strings.value(for: .contactPermissionCapsuleButtonText),
                            isCompleted: viewModel.isContactPermissionGranted
                        ) {
                            viewModel.send(.contactPermissionCapsuleButtonTapped)
                        }

                        StatusIndicatorButton(
                            viewModel.strings.value(for: .notificationPermissionCapsuleButtonText),
                            isCompleted: viewModel.isNotificationPermissionGranted
                        ) {
                            viewModel.send(.notificationPermissionCapsuleButtonTapped)
                        }
                    }
                    .padding(.bottom, Floats.buttonVStackBottomPadding)

                    Components.capsuleButton(
                        viewModel.strings.value(for: .finishButtonText),
                        font: .systemSemibold,
                        foregroundColor: viewModel.isFinishButtonEnabled ? .background : .disabled,
                        isInspectable: UIApplication.v26FeaturesEnabled
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

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.PermissionPageViewStringKey) -> String {
        (first(where: { $0.key == .permissionPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
