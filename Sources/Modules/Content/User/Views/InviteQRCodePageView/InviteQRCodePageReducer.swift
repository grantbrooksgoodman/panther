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

struct InviteQRCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case doneButtonTapped

        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var strings: [TranslationOutputMap] = InviteQRCodePageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Computed Properties */

        @MainActor
        var qrCodeImage: UIImage? {
            @Dependency(\.inviteQRCodePageViewService) var viewService: InviteQRCodePageViewService
            return viewService.appShareQRCodeImage
        }
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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
