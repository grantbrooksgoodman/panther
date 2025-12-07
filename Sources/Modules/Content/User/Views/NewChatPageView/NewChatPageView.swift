//
//  NewChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct NewChatPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.NewChatPageView
    private typealias Floats = AppConstants.CGFloats.NewChatPageView
    private typealias Strings = AppConstants.Strings.NewChatPageView

    // MARK: - Dependencies

    @ObservedDependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    @StateObject var viewModel: ViewModel<NewChatPageReducer>

    @StateObject private var observer: ViewObserver<NewChatPageObserver>

    // MARK: - Bindings

    private var sheetBinding: Binding<ChatNavigatorState.SheetPaths?> {
        navigation.navigable(
            \.chat.sheet,
            route: { .chat(.sheet($0)) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<NewChatPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    var body: some View {
        ThemedView {
            VStack {
                ChatPageView(viewModel.conversation, configuration: .newChat)
                    .ignoresSafeArea(.keyboard)
                    .background(
                        UIApplication.v26FeaturesEnabled && ThemeService.isDarkModeActive ? Color.groupedContentBackground : .background
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .if(
                UIApplication.v26FeaturesEnabled,
                { v26Layout($0) },
                else: { preV26Layout($0) }
            )
            .foregroundStyle(Color.background)
            .interactiveDismissDisabled()
            .preferredStatusBarStyle(
                .conditionalLightContent,
                restoreOnDisappear: !Application.isInPrevaricationMode
            )
            .sheet(item: sheetBinding) { sheetView(for: $0) }
            .onFirstAppear {
                viewModel.send(.viewAppeared)
            }
        }
    }

    private var doneToolbarButton: NavigationWindow.Toolbar.Item {
        .init(placement: .topBarTrailing) {
            Components.button(
                symbolName: viewModel.shouldUseBoldDoneToolbarButton ?
                    Strings.doneToolbarButtonImageSystemName :
                    Strings.cancelToolbarButtonImageSystemName,
                foregroundColor: (UIApplication.isGlassTintingEnabled && viewModel.shouldUseBoldDoneToolbarButton) ?
                    Colors.tintedGlassToolbarButtonForeground :
                    .navigationBarButton,
                weight: viewModel.shouldUseBoldDoneToolbarButton ? .bold : .semibold,
                usesIntrinsicSize: false
            ) {
                viewModel.send(.doneToolbarButtonTapped)
            }
            .frame(
                width: Floats.doneToolbarButtonFrameWidth,
                height: Floats.doneToolbarButtonFrameHeight
            )
        }
    }

    private var penPalsToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.send(.penPalsToolbarButtonTapped)
            } label: {
                (SquareIconView.image(
                    .penPalsIcon(
                        backgroundColor: viewModel.penPalsToolbarButtonBackgroundColor
                    )
                ).swiftUIImage ?? .missing)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: Floats.penPalsToolbarButtonFrameWidth,
                        height: Floats.penPalsToolbarButtonFrameHeight
                    )
            }
        }
    }

    private func preV26Layout(_ content: some View) -> some View {
        content
            .header(
                leftItem: viewModel.shouldShowPenPalsToolbarButton ? headerLeftItem : nil,
                headerCenterItem,
                rightItem: headerRightItem,
                attributes: .init(
                    showsDivider: viewModel.shouldUseBoldDoneToolbarButton,
                    sizeClass: .sheet
                )
            )
            .background(Color.background)
    }

    private func v26Layout(_ content: some View) -> some View {
        NavigationWindow(
            displayMode: .inline,
            toolbarBackgroundColor: .groupedContentBackground,
            toolbarItems: [doneToolbarButton],
            toolbarTitle: .init(viewModel.navigationTitle)
        ) {
            ZStack(alignment: .top) {
                Color.clear
                    .frame(width: .zero, height: .zero)
                    .id(viewModel.v26NavigationBarProxyViewID)
                    .ignoresSafeArea(edges: .top)
                    .navigationBarAppearance(.newChatPageView)
                    .if(viewModel.shouldUseBoldDoneToolbarButton) {
                        $0.navigationBarItemGlassTint(
                            Colors.navigationBarItemGlassTint,
                            for: .trailing
                        )
                    }

                content
                    .toolbar {
                        if viewModel.shouldShowPenPalsToolbarButton {
                            penPalsToolbarButton
                        }
                    }

                Rectangle()
                    .fill(.bar)
                    .frame(height: NavigationBar.height + Floats.navigationBarHeightIncrement)
                    .ignoresSafeArea(edges: .top)
                    .opacity(viewModel.navigationBarOpacity)
            }
        }
        .background(ThemeService.isDarkModeActive ? Color.groupedContentBackground : .background)
    }

    // MARK: - Auxiliary

    @ViewBuilder
    private func sheetView(for path: ChatNavigatorState.SheetPaths) -> some View {
        switch path {
        case .contactSelector:
            ContactSelectorPageView(.init(
                initialState: .init(.newChatPageView),
                reducer: ContactSelectorPageReducer()
            ))

        default:
            EmptyView()
        }
    }
}
