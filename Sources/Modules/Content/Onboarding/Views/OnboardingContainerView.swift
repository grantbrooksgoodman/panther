//
//  OnboardingContainerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct OnboardingContainerView: View {
    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: Navigation

    // MARK: - Bindings

    private var navigationPathBinding: Binding<[OnboardingNavigatorState.SeguePaths]> {
        navigation.navigable(
            \.onboarding.stack,
            route: { .onboarding(.stack($0)) }
        )
    }

    // MARK: - View

    @ViewBuilder
    public var body: some View {
        ZStack {
            Color.clear
                .frame(width: .zero, height: .zero)
                .preferredStatusBarStyle(ThemeService.isDarkModeActive ? .lightContent : .darkContent)
                .redrawsOnTraitCollectionChange()

            NavigationStack(path: navigationPathBinding) {
                WelcomePageView(
                    .init(
                        initialState: .init(),
                        reducer: WelcomePageReducer()
                    )
                )
                .navigationDestination(for: OnboardingNavigatorState.SeguePaths.self) { destinationView(for: $0) }
            }
        }
    }

    // MARK: - Auxiliary

    @ViewBuilder
    private func destinationView(for path: OnboardingNavigatorState.SeguePaths) -> some View {
        switch path {
        case .authCode:
            AuthCodePageView(
                .init(
                    initialState: .init(),
                    reducer: AuthCodePageReducer()
                )
            )

        case .permission:
            PermissionPageView(
                .init(
                    initialState: .init(),
                    reducer: PermissionPageReducer()
                )
            )

        case .selectLanguage:
            SelectLanguagePageView(
                .init(
                    initialState: .init(),
                    reducer: SelectLanguagePageReducer()
                )
            )

        case .signIn:
            SignInPageView(
                .init(
                    initialState: .init(),
                    reducer: SignInPageReducer()
                )
            )

        case .verifyNumber:
            VerifyNumberPageView(
                .init(
                    initialState: .init(),
                    reducer: VerifyNumberPageReducer()
                )
            )
        }
    }
}
