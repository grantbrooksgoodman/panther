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

public struct ReactionDetailsPageView: View {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ReactionDetailsPageView

    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ReactionDetailsPageObserver>
    @StateObject private var viewModel: ViewModel<ReactionDetailsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ReactionDetailsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
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
                .text(.init(viewModel.navigationTitle)),
                rightItem: .doneButton(
                    foregroundColor: Application.isInPrevaricationMode ? .navigationBarTitle : .accent
                ) { viewModel.send(.doneHeaderItemTapped) },
                attributes: .init(sizeClass: .sheet)
            )
            .preferredStatusBarStyle(
                .lightContent,
                restoreOnDisappear: !Application.isInPrevaricationMode
            )
            .onFirstAppear {
                viewModel.send(.viewAppeared)
            }
            .onDisappear {
                viewModel.send(.viewDisappeared)
            }
        }
    }
}
