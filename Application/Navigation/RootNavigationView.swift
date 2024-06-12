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
    @ViewBuilder
    var rootPage: some View {
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
                RootContainerView()
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
}

private extension View {
    func withTransition(_ view: () -> some View) -> some View {
        view()
            .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
            .zIndex(1)
    }
}
