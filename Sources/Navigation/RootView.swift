//
//  RootView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 27/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct RootView: View {
    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: NavigationCoordinator<RootNavigationService>

    // MARK: - Body

    public var body: some View {
        GeometryReader { proxy in
            rootPage
                .environment(\.mainWindowSize, proxy.size)
        }
    }

    // MARK: - Root Page

    @ViewBuilder
    private var rootPage: some View {
        switch navigation.state.modal {
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

        case .userContent:
            withTransition {
                UserContentContainerView(
                    .init(
                        initialState: .init(),
                        reducer: UserContentContainerReducer()
                    )
                )
            }

        case .none:
            EmptyView()
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
