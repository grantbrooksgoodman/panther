//
//  RootNavigationView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import CoreArchitecture

public extension RootView {
    // MARK: - Properties

    @ViewBuilder
    var rootPage: some View {
        modalView
            .sheet(item: sheetBinding) { sheetView(for: $0) }
    }

    @ViewBuilder
    private var modalView: some View {
        switch navigationCoordinator.state.modal {
        case .conversations:
            withTransition {
                ConversationsPageView(
                    .init(
                        initialState: .init(),
                        reducer: ConversationsPageReducer()
                    )
                )
            }

        case .onboarding:
            withTransition {
                OnboardingContainerView()
            }

        case .splash:
            withTransition {
                SplashPageView(
                    .init(
                        initialState: .init(),
                        reducer: SplashPageReducer()
                    )
                )
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Bindings

    private var sheetBinding: Binding<RootNavigatorState.SheetPaths?> {
        navigationCoordinator.navigable(
            \.sheet,
            route: { .root(.sheet($0)) }
        )
    }

    // MARK: - Methods

    private func sheetView(for path: RootNavigatorState.SheetPaths) -> some View {
        switch path {
        case .inviteLanguagePicker:
            InviteLanguagePickerView(
                .init(
                    initialState: .init(),
                    reducer: InviteLanguagePickerReducer()
                )
            )
        }
    }
}

private extension View {
    func withTransition(_ view: () -> some View) -> some View {
        view()
            .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
            .zIndex(1)
    }
}
