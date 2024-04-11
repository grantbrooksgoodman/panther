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

/* 3rd-party */
import Redux

public struct ConversationsContentPageView: View {
    // MARK: - Constants Accessors

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
        ThemedView(
            navigationBarAppearance: .appDefault,
            redrawsOnAppearanceChange: true
        ) {
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
                    .background(ThemeService.isDefaultThemeApplied ? Color.background : nil)
                    .listStyle(.plain)
                    .navigationTitle(viewModel.strings.value(for: .navigationTitle))
                    .refreshable {
                        viewModel.send(.pulledToRefresh)
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
            Button {
                viewModel.send(.composeToolbarButtonTapped)
            } label: {
                Label(
                    Strings.composeToolbarButtonText,
                    systemImage: Strings.composeToolbarButtonLabelImageSystemName
                )
            }
            .tint(Color.accent)
//            .disabled(!viewModel.isComposeToolbarButtonEnabled)
        }
    }

    private var settingsToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.send(.settingsToolbarButtonTapped)
            } label: {
                Label(
                    Strings.settingsToolbarButtonText,
                    systemImage: Strings.settingsToolbarButtonLabelImageSystemName
                )
            }
            .tint(Color.accent)
//            .disabled(!viewModel.isSettingsToolbarButtonEnabled)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ConversationsPageViewStringKey) -> String {
        (first(where: { $0.key == .conversationsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
