//
//  ReactionDetailsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

struct ReactionDetailsPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ReactionDetailsPageView
    private typealias Floats = AppConstants.CGFloats.ReactionDetailsPageView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ReactionDetailsPageObserver>
    @StateObject private var viewModel: ViewModel<ReactionDetailsPageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<ReactionDetailsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    var body: some View {
        ThemedView(redrawsOnAppearanceChange: true) {
            VStack {
                GroupedListView(viewModel.listItems)
                    .padding(.horizontal, Floats.groupListViewHorizontalPadding)
                    .padding(.top, Floats.groupListViewTopPadding)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(viewModel.viewID)
            .background(Color.groupedContentBackground)
            .header(
                .text(.init(viewModel.navigationTitle, foregroundColor: .navigationBarTitle)),
                rightItem: .doneButton(
                    foregroundColor: Colors.doneHeaderItemForeground
                ) { viewModel.send(.doneHeaderItemTapped) },
                attributes: .init(sizeClass: .sheet),
                usesV26Attributes: !Application.isInPrevaricationMode
            )
            .navigationBarItemGlassTint(
                Colors.navigationBarItemGlassTint,
                for: .trailing
            )
            .preferredStatusBarStyle(
                .conditionalLightContent,
                restoreOnDisappear: !Application.isInPrevaricationMode
            )
            .onFirstAppear {
                viewModel.send(.viewAppeared)
            }
            .onDisappear {
                viewModel.send(.viewDisappeared)
            }
        }
        .ignoresSafeArea()
    }
}
