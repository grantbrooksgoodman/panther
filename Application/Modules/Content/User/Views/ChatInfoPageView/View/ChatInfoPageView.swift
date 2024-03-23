//
//  ChatInfoPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ChatInfoPageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.listViewBackground)

            case .loaded:
                ChatInfoContentPageView(viewModel)

            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
        .redrawsOnTraitCollectionChange()
        .preferredStatusBarStyle(ThemeService.isDarkModeActive ? .lightContent : viewModel.preferredStatusBarStyle)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
