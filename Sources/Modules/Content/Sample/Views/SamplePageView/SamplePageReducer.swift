//
//  SamplePageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

struct SamplePageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case resolveFailed(Exception)
        case resolveReturned([TranslationOutputMap])
    }

    // MARK: - State

    struct State: Equatable {
        var strings: [TranslationOutputMap] = SamplePageViewStrings.defaultOutputMap
        var viewState: StatefulView.ViewState = .loading
    }

    // MARK: - Reduce

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
                        translator.resolve(SamplePageViewStrings.self)
                    )
                } catch {
                    return .resolveFailed(error)
                }
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
