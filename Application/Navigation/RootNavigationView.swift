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
import Redux

public extension RootView {
    var rootPage: some View {
        Group {
            switch navigationCoordinator.page {
            case .sample:
                withTransition { SamplePageView(.init(initialState: .init(), reducer: SamplePageReducer())) }

            case .splash:
                withTransition { SplashPageView(.init(initialState: .init(), reducer: SplashPageReducer())) }

            case let .onboarding(onboardingPage):
                switch onboardingPage {
                case .welcome:
                    withTransition { WelcomePageView(.init(initialState: .init(), reducer: WelcomePageReducer())) }

                case .selectLanguage:
                    withTransition { SelectLanguagePageView(.init(initialState: .init(), reducer: SelectLanguagePageReducer())) }

                case .verifyNumber:
                    withTransition { VerifyNumberPageView(.init(initialState: .init(), reducer: VerifyNumberPageReducer())) }
                }
            }
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
