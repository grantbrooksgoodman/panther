//
//  InviteLanguagePickerView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 29/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

struct InviteLanguagePickerView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.InviteLanguagePickerView
    private typealias Strings = AppConstants.Strings.InviteLanguagePickerView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<InviteLanguagePickerReducer>

    // MARK: - Bindings

    private var searchQueryBinding: Binding<String> {
        viewModel.binding(
            for: \.searchQuery,
            sendAction: { .searchQueryChanged($0) }
        )
    }

    // MARK: - Init

    init(_ viewModel: ViewModel<InviteLanguagePickerReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: .zero, height: .zero)
                .if(viewModel.isDoneHeaderItemEnabled) {
                    $0.navigationBarItemGlassTint(
                        Colors.navigationBarItemGlassTint,
                        for: .trailing
                    )
                }

            ScrollViewReader { _ in
                SearchBar.inView(withQuery: searchQueryBinding) {
                    VStack {
                        if viewModel.queriedLanguageNames.isEmpty,
                           !viewModel.searchQuery.isBlank {
                            noResultsView
                        } else {
                            listView(
                                languageNames: viewModel.queriedLanguageNames.isEmpty ? viewModel.localizedLanguageNames : viewModel.queriedLanguageNames
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.groupedContentBackground)
                }
            }
        }
        .header(
            leftItem: .cancelButton(foregroundColor: .navigationBarButton) {
                viewModel.send(.cancelHeaderItemTapped)
            },
            .text(.init(viewModel.navigationTitle, foregroundColor: .navigationBarTitle)),
            rightItem: .doneButton(
                foregroundColor: viewModel.isDoneHeaderItemEnabled ? Colors.doneHeaderItemForeground :
                    .disabled,
                isEnabled: viewModel.isDoneHeaderItemEnabled
            ) {
                viewModel.send(.doneHeaderItemTapped)
            },
            attributes: .init(
                restoreOnDisappear: false, // TODO: Audit this.
                showsDivider: false,
                sizeClass: .sheet
            ),
            usesV26Attributes: !Application.isInPrevaricationMode
        )
        .background(Color.navigationBarBackground)
        .ignoresSafeArea()
        .interactiveDismissDisabled(true)
        .preferredStatusBarStyle(
            .conditionalLightContent,
            restoreOnDisappear: !Application.isInPrevaricationMode
        )
        .onAppear {
            viewModel.send(.viewAppeared)
        }
        .onNavigationTransition(.didDisappear) { _ in
            viewModel.send(.viewDisappeared)
        }
        .onTraitCollectionChange {
            let previousQuery = viewModel.searchQuery
            viewModel.send(.searchQueryChanged(" "))
            viewModel.send(.searchQueryChanged(previousQuery.isBlank ? "" : previousQuery))
        }
    }

    private func listView(languageNames: [String: String]) -> some View {
        List {
            ForEach(languageNames.sorted(by: { $0.value < $1.value }).map(\.key), id: \.self) { key in
                Button {
                    viewModel.send(.selectedLanguageCodeChanged(key))
                } label: {
                    HStack {
                        Components.text(
                            languageNames[key]!,
                            font: key == viewModel.selectedLanguageCode ? .systemSemibold : .system
                        )

                        Spacer()

                        if key == viewModel.selectedLanguageCode {
                            Components.symbol(
                                Strings.selectedCellImageSystemName,
                                foregroundColor: Colors.selectedCellImageForeground
                            )
                        }
                    }
                }
            }
        }
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
