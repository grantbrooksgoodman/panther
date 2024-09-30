//
//  ConversationsContentPageView.swift
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

public struct ConversationsContentPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ConversationsPageView
    private typealias Strings = AppConstants.Strings.ConversationsPageView

    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Bindings

    private var newChatSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingNewChatSheet,
            sendAction: { .isPresentingNewChatSheetChanged($0) }
        )
    }

    private var settingsSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingSettingsSheet,
            sendAction: { .isPresentingSettingsSheetChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView(navigationBarAppearance: .appDefault) {
            VStack {
                NavigationView {
                    List {
                        ForEach(viewModel.conversations, id: \.self) { conversation in
                            ConversationCellView(
                                .init(
                                    initialState: .init(conversation),
                                    reducer: ConversationCellReducer()
                                )
                            )
                        }
                    }
                    .background(ThemeService.isAppDefaultThemeApplied ? Color.background : nil)
                    .listStyle(.plain)
                    .navigationTitle(viewModel.strings.value(for: .navigationTitle))
                    .refreshable {
                        await viewModel.send(.pulledToRefresh, while: \.isRefreshing)
                    }
                    .toolbar {
                        composeToolbarButton
                        settingsToolbarButton
                    }
                }
                .accentColor(Color.accent)
                .id(viewModel.viewID)
            }
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
        .preferredStatusBarStyle(ThemeService.isDarkModeActive ? .lightContent : .darkContent)
        .sheet(isPresented: newChatSheetBinding) {
            NewChatPageView(
                .init(
                    initialState: .init(newChatSheetBinding),
                    reducer: NewChatPageReducer()
                )
            )
        }
        .sheet(isPresented: settingsSheetBinding) {
            SettingsPageView(
                .init(
                    initialState: .init(settingsSheetBinding),
                    reducer: SettingsPageReducer()
                )
            )
        }
    }

    private var composeToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.conversations.isEmpty {
                Components.button(
                    symbolName: Strings.composeToolbarButtonLabelImageSystemName,
                    usesIntrinsicSize: false
                ) {
                    viewModel.send(.composeToolbarButtonTapped)
                }
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
            } else {
                Components.button(
                    symbolName: Strings.composeToolbarButtonLabelImageSystemName,
                    usesIntrinsicSize: false
                ) {
                    viewModel.send(.composeToolbarButtonTapped)
                }
            }
        }
    }

    private var settingsToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Components.button(
                symbolName: Strings.settingsToolbarButtonLabelImageSystemName,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.settingsToolbarButtonTapped)
            }
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ConversationsPageViewStringKey) -> String {
        (first(where: { $0.key == .conversationsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
