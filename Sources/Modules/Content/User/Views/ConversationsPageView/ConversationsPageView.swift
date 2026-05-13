//
//  ConversationsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct ConversationsPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ConversationsPageView
    private typealias Floats = AppConstants.CGFloats.ConversationsPageView
    private typealias Strings = AppConstants.Strings.ConversationsPageView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ConversationsPageObserver>
    @StateObject private var viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Bindings

    private var isSearchingBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isSearching,
            sendAction: { .isSearchingChanged($0) }
        )
    }

    private var searchQueryBinding: Binding<String> {
        viewModel.binding(
            for: \.searchQuery,
            sendAction: { .searchQueryChanged($0) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    var body: some View {
        StatefulView(viewModel.binding(for: \.viewState)) {
            ThemedView {
                VStack {
                    NavigationWindow(
                        isBackButtonHidden: true,
                        toolbarItems: [settingsToolbarButton],
                        toolbarTitle: .init(
                            viewModel.strings.value(
                                for: Application.isInPrevaricationMode ? .prevaricationModeNavigationTitle : .navigationTitle
                            )
                        )
                    ) {
                        List {
                            ForEach(viewModel.conversations, id: \.self) { conversation in
                                ConversationCellView(
                                    .init(
                                        initialState: .init(
                                            conversation,
                                            searchQuery: viewModel.searchQuery
                                        ),
                                        reducer: ConversationCellReducer()
                                    )
                                )
                                .redrawsOnTraitCollectionChange()
                            }
                        }
                        .background(ThemeService.isAppDefaultThemeApplied ? Color.background : nil)
                        .id(viewModel.conversationCellViewID)
                        .listStyle(.plain)
                        .if(!viewModel.isSearching) {
                            $0.refreshable {
                                await viewModel.send(
                                    .pulledToRefresh,
                                    while: \.isRefreshing
                                )
                            } // NIT: Not sure why this works to restore the refresh control.
                            .if(UIApplication.isFullyV26Compatible) {
                                $0.background(EmptyUIView())
                            }
                        }
                        .searchable(
                            text: searchQueryBinding,
                            isPresented: isSearchingBinding,
                            placement: .navigationBarDrawer(displayMode: .automatic),
                            prompt: Localized(.search).wrappedValue
                        )
                        .if(
                            viewModel.shouldShowExtraToolbarButtons
                        ) {
                            $0.toolbar {
                                deleteConversationsToolbarButton
                                createRandomMessagesToolbarButton
                                composeToolbarButton
                            }
                        } else: {
                            $0.toolbar { composeToolbarButton }
                        }
                    }
                    .if(!ThemeService.isAppDefaultThemeApplied) {
                        $0.navigationBarItemGlassTint(
                            .accent,
                            for: .leading, .trailing
                        )
                    }
                }
            }
        }
        .if(Application.isInPrevaricationMode && UIApplication.isFullyV26Compatible) {
            $0
                .preferredStatusBarStyle(.darkContent)
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
        .onDisappear {
            viewModel.send(.viewDisappeared)
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
    }

    private var composeToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) { // swiftlint:disable:next line_length
            let symbolName = viewModel.shouldShowStorageFullButton ? Strings.storageFullToolbarButtonImageSystemName : Strings.composeToolbarButtonImageSystemName
            let foregroundColor = viewModel.shouldShowStorageFullButton ? Colors.storageFullToolbarButtonForeground : Colors.composeToolbarButtonForeground

            Components.button(
                symbolName: symbolName,
                foregroundColor: foregroundColor,
                secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.composeToolbarButtonTapped)
            }
            .id(viewModel.composeToolbarButtonViewID)
            .frame(
                minWidth: Floats.toolbarButtonFrameMinWidth,
                minHeight: Floats.toolbarButtonFrameMinHeight
            )
            .if(viewModel.conversations.isEmpty || viewModel.shouldShowStorageFullButton) {
                $0
                    .scaleEffect(viewModel.animationAmount)
                    .animation(
                        .linear(duration: Floats.composeToolbarButtonAnimationDuration)
                            .delay(Floats.composeToolbarButtonAnimationDelay)
                            .repeatForever(autoreverses: true),
                        value: viewModel.animationAmount
                    )
                    .onAppear {
                        viewModel.send(.animatedComposeToolbarButtonAppeared)
                    }
            }
        }
    }

    private var createRandomMessagesToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(
                symbolName: Strings.createRandomMessagesToolbarButtonImageSystemName,
                foregroundColor: Colors.createRandomMessagesToolbarButtonForeground,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.createRandomMessagesToolbarButtonTapped)
            }
            .frame(
                minWidth: Floats.toolbarButtonFrameMinWidth,
                minHeight: Floats.toolbarButtonFrameMinHeight
            )
        }
    }

    private var deleteConversationsToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Components.button(
                symbolName: Strings.deleteConversationsToolbarButtonImageSystemName,
                foregroundColor: Colors.deleteConversationsToolbarButtonForeground,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.deleteConversationsToolbarButtonTapped)
            }
            .frame(
                minWidth: Floats.toolbarButtonFrameMinWidth,
                minHeight: Floats.toolbarButtonFrameMinHeight
            )
        }
    }

    private var settingsToolbarButton: NavigationWindow.Toolbar.Item {
        .init(placement: .topBarLeading) {
            Components.button(
                symbolName: Strings.settingsToolbarButtonImageSystemName,
                foregroundColor: Colors.settingsToolbarButtonForeground,
                secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.settingsToolbarButtonTapped)
            }
            .frame(
                minWidth: Floats.toolbarButtonFrameMinWidth,
                minHeight: Floats.toolbarButtonFrameMinHeight
            )
        }
    }
}

private extension [TranslationOutputMap] {
    func value(for key: TranslatedLabelStringCollection.ConversationsPageViewStringKey) -> String {
        (first(where: { $0.key == .conversationsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
