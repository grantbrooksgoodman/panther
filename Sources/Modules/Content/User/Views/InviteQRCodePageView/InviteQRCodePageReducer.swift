//
//  InviteQRCodePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// The reducer that drives the invite QR code page.
///
/// This page displays a QR code that others can scan to be invited to the app.
///
/// The page's behavior contract:
///
/// - On appearance, the page resolves its translated display strings, remaining in the loading
///   state until resolution completes. If resolution fails, the page loads anyway.
/// - Tapping done dismisses the page.
struct InviteQRCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    /// The actions the invite QR code page can process.
    enum Action {
        /// An action that indicates the view appeared. Begins display string resolution.
        case viewAppeared

        /// An action that indicates the user tapped the done button. Dismisses the page.
        case doneButtonTapped

        /// An action that indicates display string resolution failed, carrying the resulting
        /// `Exception`.
        case resolveFailed(Exception)

        /// An action that indicates display string resolution succeeded, carrying the resolved
        /// strings.
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    /// The state of the invite QR code page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The page's translated display strings. Contains the default, untranslated strings
        /// until resolution completes.
        var strings: [TranslationOutputMap] = InviteQRCodePageViewStrings.defaultOutputMap

        /// The page's loading state. Remains `loading` until display string resolution completes.
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        /// The QR code image for inviting others to the app, or `nil` if it is not available.
        @MainActor
        var qrCodeImage: UIImage? {
            @Dependency(\.inviteQRCodePageViewService) var viewService: InviteQRCodePageViewService
            return viewService.appShareQRCodeImage
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            return .task {
                do throws(Exception) {
                    return try await .resolveReturned(
                        translator.resolve(InviteQRCodePageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
            }

        case .doneButtonTapped:
            navigation.navigate(to: .settings(.sheet(nil)))
            if !Application.isInPrevaricationMode,
               ThemeService.isAppDefaultThemeApplied,
               !ThemeService.isDarkModeActive {
                StatusBar.overrideStyle(.darkContent)
            }

        case let .resolveFailed(exception):
            Logger.log(exception)
            state.viewState = .loaded

        case let .resolveReturned(strings):
            state.strings = strings
            state.viewState = .loaded
        }

        return .none
    }
}
