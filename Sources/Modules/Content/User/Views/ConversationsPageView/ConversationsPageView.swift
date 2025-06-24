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

public struct ConversationsPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ConversationsPageView
    private typealias Floats = AppConstants.CGFloats.ConversationsPageView
    private typealias Strings = AppConstants.Strings.ConversationsPageView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ConversationsPageObserver>
    @StateObject private var viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
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
                                        initialState: .init(conversation),
                                        reducer: ConversationCellReducer()
                                    )
                                )
                                .redrawsOnTraitCollectionChange()
                            }
                        }
                        .background(ThemeService.isAppDefaultThemeApplied ? Color.background : nil)
                        .listStyle(.plain)
                        .refreshable {
                            await viewModel.send(.pulledToRefresh, while: \.isRefreshing)
                        }
                        .toolbar { composeToolbarButton }
                    }
                }
            }
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
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(
                symbolName: Strings.composeToolbarButtonLabelImageSystemName,
                foregroundColor: Colors.composeToolbarButtonForeground,
                secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.composeToolbarButtonTapped)
            }
            .if(viewModel.conversations.isEmpty) {
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

    private var settingsToolbarButton: NavigationWindow.Toolbar.Item {
        .init(placement: .topBarLeading) {
            Components.button(
                symbolName: Strings.settingsToolbarButtonLabelImageSystemName,
                foregroundColor: Colors.settingsToolbarButtonForeground,
                secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
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
