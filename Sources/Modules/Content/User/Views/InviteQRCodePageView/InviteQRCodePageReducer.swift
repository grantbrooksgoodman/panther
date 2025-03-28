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

public struct InviteQRCodePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case doneButtonTapped

        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Types */

        public enum ViewState: Equatable {
            case loading
            case error(Exception)
            case loaded
        }

        /* MARK: Properties */

        public var strings: [TranslationOutputMap] = InviteQRCodePageViewStrings.defaultOutputMap
        public var viewState: ViewState = .loading

        /* MARK: Computed Properties */

        public var qrCodeImage: UIImage? {
            @Dependency(\.inviteQRCodePageViewService) var viewService: InviteQRCodePageViewService
            return viewService.appShareQRCodeImage
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading
            return .task {
                let result = await translator.resolve(InviteQRCodePageViewStrings.self)
                return .resolveReturned(result)
            }

        case .doneButtonTapped:
            navigation.navigate(to: .settings(.sheet(nil)))
            if !Application.isInPrevaricationMode,
               ThemeService.isAppDefaultThemeApplied,
               !ThemeService.isDarkModeActive {
                StatusBarStyle.override(.darkContent)
            }

        case let .resolveReturned(.success(strings)):
            state.strings = strings
            state.viewState = .loaded

        case let .resolveReturned(.failure(exception)):
            Logger.log(exception)
            state.viewState = .loaded
        }

        return .none
    }
}
