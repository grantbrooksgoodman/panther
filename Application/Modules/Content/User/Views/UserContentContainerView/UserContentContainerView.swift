//
//  UserContentContainerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct UserContentContainerView: View {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.UserContentContainerView

    // MARK: - Properties

    @ObservedNavigator private var navigationCoordinator: NavigationCoordinator<RootNavigationService>
    @StateObject private var viewModel: ViewModel<UserContentContainerReducer>

    // MARK: - Bindings

    private var navigationPathBinding: Binding<[UserContentNavigatorState.SeguePaths]> {
        navigationCoordinator.navigable(
            \.userContent.stack,
            route: { .userContent(.stack($0)) }
        )
    }

    private var sheetBinding: Binding<UserContentNavigatorState.SheetPaths?> {
        navigationCoordinator.navigable(
            \.userContent.sheet,
            route: { .userContent(.sheet($0)) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<UserContentContainerReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    @ViewBuilder
    public var body: some View {
        NavigationStack(path: navigationPathBinding) {
            ConversationsPageView(
                .init(
                    initialState: .init(),
                    reducer: ConversationsPageReducer()
                )
            )
            .navigationDestination(for: UserContentNavigatorState.SeguePaths.self) { destinationView(for: $0) }
            .sheet(item: sheetBinding) { sheetView(for: $0) }
        }
    }

    // MARK: - Auxiliary

    private func chatPageView(_ conversation: Conversation) -> some View {
        ChatPageView(
            conversation,
            configuration: .default
        )
        .background(ThemeService.isAppDefaultThemeApplied ? .clear : .navigationBarBackground)
        .ignoresSafeArea(.keyboard)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(ConversationCellViewData(conversation)?.titleLabelText ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Components.button(
                    symbolName: Strings.chatInfoButtonImageSystemName,
                    usesIntrinsicSize: false
                ) {
                    viewModel.send(.chatInfoToolbarButtonTapped)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for path: UserContentNavigatorState.SeguePaths) -> some View {
        switch path {
        case let .chat(conversation):
            chatPageView(conversation)
        }
    }

    @ViewBuilder
    private func sheetView(for path: UserContentNavigatorState.SheetPaths) -> some View {
        switch path {
        case .newChat:
            NewChatPageView(
                .init(
                    initialState: .init(),
                    reducer: NewChatPageReducer()
                )
            )

        case .settings:
            SettingsPageView(
                .init(
                    initialState: .init(),
                    reducer: SettingsPageReducer()
                )
            )
        }
    }
}
