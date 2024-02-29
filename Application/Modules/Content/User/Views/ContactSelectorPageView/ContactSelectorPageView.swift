//
//  ContactSelectorPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ContactSelectorPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ContactSelectorPageView
    private typealias Floats = AppConstants.CGFloats.ContactSelectorPageView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<ContactSelectorPageReducer>

    // MARK: - Bindings

    private var searchQueryBinding: Binding<String> {
        viewModel.binding(
            for: \.searchQuery,
            sendAction: { .searchQueryChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<ContactSelectorPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(searchQueryBinding)

                if !viewModel.queriedContactPairs.isEmpty {
                    listView
                } else {
                    noResultsView
                }
            }
            .toolbar {
                cancelToolbarButton
                inviteToolbarButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(viewModel.navigationTitle)
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
        .redrawsOnTraitCollectionChange()
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    private var cancelToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(viewModel.cancelToolbarButtonText) {
                viewModel.send(.cancelToolbarButtonTapped)
            }
            .foregroundStyle(Color.accent)
        }
    }

    private var inviteToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                viewModel.send(.inviteToolbarButtonTapped)
            } label: {
                Text(viewModel.inviteToolbarButtonText)
                    .font(Font.body.bold())
                    .foregroundStyle(Color.accent)
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(Array(viewModel.sections.keys).alphabeticallySorted, id: \.self) { letter in
                if let pairsForLetter = viewModel.sections[letter] {
                    Section(header: Text(letter)) {
                        ForEach(0 ..< pairsForLetter.count, id: \.self) { index in
                            if let contactPair = pairsForLetter.itemAt(index) {
                                ContactPairCellView(contactPair: contactPair) {
                                    viewModel.send(.selectedContactPairChanged(contactPair))
                                }
                            }
                        }
                    }
                    .id(letter)
                }
            }
        }
        .environment(\.defaultMinListRowHeight, Floats.listViewDefaultMinListRowHeight)
        .listStyle(.inset)
    }

    private var noResultsView: some View {
        Group {
            Spacer()
            Text(viewModel.noResultsLabelText)
                .font(.system(size: Floats.noResultsLabelSystemFontSize, weight: .regular))
                .foregroundStyle(Colors.noResultsLabelForeground)
            Spacer()
        }
    }
}
