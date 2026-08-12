//
//  StatusIndicatorButton.swift
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

/// A capsule-shaped button that displays the status of an onboarding task alongside a text label.
///
/// Use ``StatusIndicatorButton`` to represent a task the user must complete during onboarding,
/// such as granting a system permission. The button pairs a status symbol with the given text and
/// runs an action when tapped.
///
/// The button's appearance and interactivity derive from a tri-state completion value:
///
/// - `nil` indicates the task's status is undetermined. The button is enabled, and tapping it runs
///   the given action.
/// - `true` indicates the task completed successfully. The button is disabled and displays a
///   confirmation symbol.
/// - `false` indicates the task failed or was declined. The button is disabled and displays a
///   failure symbol.
///
/// ```swift
/// StatusIndicatorButton(
///     "Allow Notifications",
///     isCompleted: viewModel.isNotificationPermissionGranted
/// ) {
///     viewModel.send(.notificationPermissionCapsuleButtonTapped)
/// }
/// ```
///
/// - Important: Once the completion value becomes non-`nil`, the button no longer responds to
///   taps. To let the user retry a failed task, reset the value to `nil`.
struct StatusIndicatorButton: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.StatusIndicatorButton
    private typealias Floats = AppConstants.CGFloats.StatusIndicatorButton
    private typealias Strings = AppConstants.Strings.StatusIndicatorButton

    // MARK: - Properties

    private let action: () -> Void
    private let isCompleted: Bool?
    private let text: String

    // MARK: - Computed Properties

    private var imageSecondaryForegroundColor: Color {
        guard let isCompleted else { return Colors.undeterminedStatusImageSecondaryForeground }
        return isCompleted ? Colors.grantedStatusImageSecondaryForeground : Colors.deniedStatusImageSecondaryForeground
    }

    private var imageSystemName: String {
        guard let isCompleted else { return Strings.undeterminedStatusImageSystemName }
        return isCompleted ? Strings.grantedStatusImageSystemName : Strings.deniedStatusImageSystemName
    }

    // MARK: - Init

    /// Creates a status indicator button with the given label text, completion state, and action.
    ///
    /// - Parameters:
    ///   - text: The text to display as the button's label.
    ///   - isCompleted: The completion state of the task the button represents. Pass `nil` while
    ///     the status is undetermined; pass `true` or `false` once the task has resolved. Any
    ///     non-`nil` value disables the button.
    ///   - action: The action to perform when the user taps the button. The button ignores taps
    ///     while `isCompleted` is non-`nil`.
    init(
        _ text: String,
        isCompleted: Bool?,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.isCompleted = isCompleted
        self.action = action
    }

    // MARK: - View

    /// The content and behavior of the view.
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Components.symbol(
                    imageSystemName,
                    foregroundColor: .white,
                    secondaryForegroundColor: imageSecondaryForegroundColor,
                    usesIntrinsicSize: false
                )
                .frame(width: Floats.imageFrameWidth, height: Floats.imageFrameHeight)
                .padding(.trailing, Floats.imageTrailingPadding)

                Components.text(
                    text,
                    font: .systemBold(scale: .custom(Floats.labelFontSize)),
                    foregroundColor: isCompleted == nil ? Colors.undeterminedStatusLabelForeground : Colors.determinedStatusLabelForeground
                )
            }
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .disabled(isCompleted == nil ? false : true)
        .foregroundStyle(Colors.foreground)
    }
}
