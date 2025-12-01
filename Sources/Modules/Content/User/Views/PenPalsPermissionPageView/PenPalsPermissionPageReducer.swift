//
//  PenPalsPermissionPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

struct PenPalsPermissionPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.networking.hostedTranslation) private var translator: HostedTranslationDelegate

    // MARK: - Actions

    enum Action {
        case viewAppeared

        case dismissButtonTapped
        case enableButtonTapped

        case resolveReturned(Callback<[TranslationOutputMap], Exception>)
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        var strings: [TranslationOutputMap] = PenPalsPermissionPageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading

        /* MARK: Init */

        init() {}
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            state.viewState = .loading

            return .task {
                let result = await translator.resolve(PenPalsPermissionPageViewStrings.self)
                return .resolveReturned(result)
            }

        case .dismissButtonTapped:
            RootSheets.dismiss()
            return .fireAndForget {
                if let exception = await penPalsService.setDidGrantPenPalsPermission(false) {
                    Logger.log(exception, with: .toastInPrerelease)
                }
            }

        case .enableButtonTapped:
            RootSheets.dismiss()
            return .fireAndForget {
                if let exception = await penPalsService.setDidGrantPenPalsPermission(true) {
                    Logger.log(exception, with: .toastInPrerelease)
                }
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
