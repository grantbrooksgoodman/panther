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

public struct InviteLanguagePickerView: View {
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

    public init(_ viewModel: ViewModel<InviteLanguagePickerReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        ScrollViewReader { _ in
            SearchBar(searchQueryBinding)

            VStack {
                if viewModel.queriedLanguageNames.isEmpty,
                   !viewModel.searchQuery.isBlank {
                    noResultsView
                } else {
                    listView(languageNames: viewModel.queriedLanguageNames.isEmpty ? viewModel.localizedLanguageNames : viewModel.queriedLanguageNames)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.listViewBackground)
            .interactiveDismissDisabled(true)
        }
        .header(
            leftItem: .cancelButton { viewModel.send(.cancelHeaderItemTapped) },
            .text(.init(viewModel.navigationTitle)),
            rightItem: .doneButton(foregroundColor: viewModel.isDoneHeaderItemEnabled ? .accent : .disabled) { viewModel.send(.doneHeaderItemTapped) },
            attributes: .init(showsDivider: false, sizeClass: .sheet)
        )
        .background(Color.navigationBarBackground)
        .ignoresSafeArea()
        .interfaceStyle(ThemeService.isDarkModeActive ? .dark : .light)
        .preferredStatusBarStyle(.lightContent)
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
        .onAppear {
            viewModel.send(.viewAppeared)
        }
        .onDisappear {
            viewModel.send(.viewDisappeared)
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
