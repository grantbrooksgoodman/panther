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

struct UserContentContainerView: View {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.UserContentContainerView
    private typealias Floats = AppConstants.CGFloats.UserContentContainerView

    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<UserContentContainerReducer>

    // MARK: - Bindings

    private var navigationPathBinding: Binding<[UserContentNavigatorState.SeguePaths]> {
        navigation.navigable(
            \.userContent.stack,
            route: { .userContent(.stack($0)) }
        )
    }

    private var sheetBinding: Binding<UserContentNavigatorState.SheetPaths?> {
        navigation.navigable(
            \.userContent.sheet,
            route: { .userContent(.sheet($0)) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<UserContentContainerReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    @ViewBuilder
    var body: some View {
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
        .interfaceStyle(Application.isInPrevaricationMode ? .light : ThemeService.currentTheme.style)
    }

    // MARK: - Auxiliary

    private var chatInfoToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(
                symbolName: Strings.chatInfoButtonImageSystemName,
                foregroundColor: .navigationBarButton,
                secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.chatInfoToolbarButtonTapped)
            }
            .frame(
                minWidth: Floats.chatInfoToolbarButtonFrameMinWidth,
                minHeight: Floats.chatInfoToolbarButtonFrameMinHeight
            )
        }
    }

    @ViewBuilder
    private func chatPageView(
        _ conversation: Conversation,
        focusedMessageID: String?
    ) -> some View {
        let baseView = ChatPageView(
            conversation,
            configuration: .default(focusedMessageID: focusedMessageID)
        )
        .background(ThemeService.isAppDefaultThemeApplied ? .clear : .navigationBarBackground)
        .ignoresSafeArea(.keyboard)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(ConversationCellViewData(conversation)?.titleLabelText ?? "")
        .toolbarRole(.editor)

        if UIApplication.v26FeaturesEnabled {
            ZStack {
                ThemedView {
                    Color.clear
                        .frame(width: .zero, height: .zero)
                        .toolbar {
                            chatInfoToolbarButton
                        }
                }

                baseView
            }
        } else {
            baseView
                .toolbar {
                    chatInfoToolbarButton
                }
        }
    }

    @ViewBuilder
    private func destinationView(for path: UserContentNavigatorState.SeguePaths) -> some View {
        switch path {
        case let .chat(conversation, focusedMessageID: focusedMessageID):
            chatPageView(
                conversation,
                focusedMessageID: focusedMessageID
            )
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
