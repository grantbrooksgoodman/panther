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
                .preferredStatusBarStyle(.appAware)
                .redrawsOnTraitCollectionChange()

            NavigationStack(path: navigationPathBinding) {
                ThemedView {
                    WelcomePageView(
                        .init(
                            initialState: .init(),
                            reducer: WelcomePageReducer()
                        )
                    )
                    .navigationDestination(for: OnboardingNavigatorState.SeguePaths.self) {
                        destinationView(for: $0)
                    }
                }
            }
        }
    }

    // MARK: - Auxiliary

    @ViewBuilder
    private func destinationView(for path: OnboardingNavigatorState.SeguePaths) -> some View {
        switch path {
        case .authCode:
            ThemedView {
                AuthCodePageView(
                    .init(
                        initialState: .init(),
                        reducer: AuthCodePageReducer()
                    )
                )
            }

        case .permission:
            ThemedView {
                PermissionPageView(
                    .init(
                        initialState: .init(),
                        reducer: PermissionPageReducer()
                    )
                )
            }

        case .selectLanguage:
            ThemedView {
                SelectLanguagePageView(
                    .init(
                        initialState: .init(),
                        reducer: SelectLanguagePageReducer()
                    )
                )
            }

        case .signIn:
            ThemedView {
                SignInPageView(
                    .init(
                        initialState: .init(),
                        reducer: SignInPageReducer()
                    )
                )
            }

        case .verifyNumber:
            ThemedView {
                VerifyNumberPageView(
                    .init(
                        initialState: .init(),
                        reducer: VerifyNumberPageReducer()
                    )
                )
            }
        }
    }
}
