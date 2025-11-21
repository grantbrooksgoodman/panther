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

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct ContactSelectorPageView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ContactSelectorPageView
    private typealias Floats = AppConstants.CGFloats.ContactSelectorPageView

    // MARK: - Types

    public enum EntryPoint {
        case chatInfoPageView
        case newChatPageView
    }

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

    // MARK: - Body

    public var body: some View {
        SearchBar.inView(withQuery: searchQueryBinding) {
            Group {
                if !viewModel.queriedContactPairs.isEmpty {
                    listView
                } else {
                    noResultsView
                }
            }
        }
        .v26Header(
            leftItem: viewModel.entryPoint == .chatInfoPageView ? nil : headerLeftItem,
            .text(.init(viewModel.navigationTitle, foregroundColor: .navigationBarTitle)),
            rightItem: headerRightItem,
            attributes: .init(
                appearance: Application.isInPrevaricationMode ? .custom(backgroundColor: .navigationBarBackground) : .themed,
                showsDivider: false,
                sizeClass: .sheet
            )
        )
        .if(
            viewModel.entryPoint == .newChatPageView,
            { body in
                body
                    .navigationBarItemGlassTint(
                        Colors.navigationBarItemGlassTint,
                        for: .leading
                    )
                    .redrawsOnTraitCollectionChange()
            },
            else: { body in
                body
                    .interfaceStyle(ThemeService.isDarkModeActive ? .dark : .light)
                    .onTraitCollectionChange {
                        viewModel.send(.traitCollectionChanged)
                    }
                    .onDisappear {
                        viewModel.send(.viewDisappeared)
                    }
            }
        )
    }

    // MARK: - Header Items

    private var headerLeftItem: HeaderView.PeripheralButtonType {
        .text(
            .init(
                text: .init(
                    viewModel.inviteToolbarButtonText,
                    foregroundColor: UIApplication.isGlassTintingEnabled && viewModel.entryPoint == .newChatPageView ?
                        Colors.tintedGlassToolbarButtonForeground
                        : .navigationBarButton
                )
            ) { viewModel.send(.inviteToolbarButtonTapped) }
        )
    }

    private var headerRightItem: HeaderView.PeripheralButtonType {
        .cancelButton(
            font: .system(size: Floats.cancelToolbarButtonSystemFontSize),
            foregroundColor: .navigationBarButton
        ) { viewModel.send(.cancelToolbarButtonTapped) }
    }

    // MARK: - List View

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

    // MARK: - No Results View

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
