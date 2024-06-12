//
//  SettingsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import CoreArchitecture

public struct SettingsPageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<SettingsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SettingsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressPageView()
            case .loaded:
                SettingsContentPageView(viewModel)
            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .navigationBarAppearance(.default())
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
        .onTraitCollectionChange {
            viewModel.send(.traitCollectionChanged)
        }
        .redrawsOnTraitCollectionChange()
        .onDisappear {
            viewModel.send(.viewDisappeared)
        }
    }
}
