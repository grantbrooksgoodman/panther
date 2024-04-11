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

/* 3rd-party */
import Redux

public struct InviteLanguagePickerView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.InviteLanguagePickerView
    private typealias Floats = AppConstants.CGFloats.InviteLanguagePickerView
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
            .interactiveDismissDisabled(true)
        }
        .header(
            leftItem: cancelHeaderItem,
            .text(.init(viewModel.navigationTitle)),
            rightItem: doneHeaderItem,
            showsDivider: false
        )
        .background(Color.navigationBarBackground)
        .ignoresSafeArea()
        .interfaceStyle(ThemeService.isDarkModeActive ? .dark : .light)
        .preferredStatusBarStyle(.lightContent)
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
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
                        Text(languageNames[key]!)
                            .font(.system(
                                size: Floats.cellLabelSystemFontSize,
                                weight: key == viewModel.selectedLanguageCode ? .bold : .regular
                            ))
                            .foregroundStyle(Color.titleText)

                        Spacer()

                        if key == viewModel.selectedLanguageCode {
                            Image(systemName: Strings.selectedCellImageSystemName)
                                .imageScale(.medium)
                                .foregroundStyle(Colors.selectedCellImageForeground)
                        }
                    }
                }
            }
        }
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

    // MARK: - Header Items

    private var cancelHeaderItem: HeaderView.PeripheralButtonType {
        .text(
            .init(text: .init(
                viewModel.cancelHeaderItemText,
                font: .system(size: Floats.headerItemSystemFontSize),
                foregroundColor: .accent
            )) {
                viewModel.send(.cancelHeaderItemTapped)
            }
        )
    }

    private var doneHeaderItem: HeaderView.PeripheralButtonType {
        .text(
            .init(text: .init(
                viewModel.doneHeaderItemText,
                font: .system(size: Floats.headerItemSystemFontSize, weight: .semibold),
                foregroundColor: viewModel.isDoneHeaderItemEnabled ? .accent : .disabled
            )) {
                if viewModel.isDoneHeaderItemEnabled {
                    viewModel.send(.doneHeaderItemTapped)
                }
            }
        )
    }
}
