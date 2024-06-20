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
import ComponentKit
import CoreArchitecture

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
        .navigationBarAppearance(.themed(showsDivider: false))
    }

    private var cancelToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(viewModel.cancelToolbarButtonText) {
                viewModel.send(.cancelToolbarButtonTapped)
            }
        }
    }

    private var inviteToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Components.button(
                viewModel.inviteToolbarButtonText,
                font: .systemSemibold
            ) {
                viewModel.send(.inviteToolbarButtonTapped)
            }
        }
    }

    private var listView: some View {
        List {
            ForEach(Array(viewModel.sections.keys).alphabeticallySorted, id: \.self) { letter in
                if let pairsForLetter = viewModel.sections[letter] {
                    Section(header: Components.text(letter)) {
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
            Components.text(
                viewModel.noResultsLabelText,
                foregroundColor: Colors.noResultsLabelForeground
            )
            Spacer()
        }
    }
}
