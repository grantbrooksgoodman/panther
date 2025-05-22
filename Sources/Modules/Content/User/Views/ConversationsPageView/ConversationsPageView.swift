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
                    NavigationView {
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
                        .navigationTitle(viewModel.strings.value(
                            for: Application.isInPrevaricationMode ? .prevaricationModeNavigationTitle : .navigationTitle
                        ))
                        .refreshable {
                            await viewModel.send(.pulledToRefresh, while: \.isRefreshing)
                        }
                        .toolbar {
                            composeToolbarButton
                            settingsToolbarButton
                        }
                    }
                    .accentColor(Color.accent)
                }
            }
            .navigationBarBackButtonHidden()
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
            if viewModel.conversations.isEmpty {
                Components.button(
                    symbolName: Strings.composeToolbarButtonLabelImageSystemName,
                    foregroundColor: .accent,
                    secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
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
                    foregroundColor: .accent,
                    secondaryForegroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : nil,
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
                foregroundColor: .accent,
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
