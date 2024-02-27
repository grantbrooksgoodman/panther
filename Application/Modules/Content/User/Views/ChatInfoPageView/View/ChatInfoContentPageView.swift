//
//  ChatInfoContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ChatInfoContentPageView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            NavigationView {
                VStack {
                    Text("Hello world")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.listViewBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    doneToolbarButton
                }
            }
            .accentColor(Color.accent)
            .interactiveDismissDisabled(true)
            .toolbarBackground(Color.navigationBarBackground, for: .navigationBar)
        }
        .onTraitCollectionChange { viewModel.send(.traitCollectionChanged) }
        .redrawsOnTraitCollectionChange()
        .preferredStatusBarStyle(.lightContent)
    }

    private var doneToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.send(.doneToolbarButtonTapped)
            } label: {
                Text(viewModel.doneToolbarButtonText)
                    .bold()
                    .foregroundStyle(Color.accent)
            }
        }
    }
}
