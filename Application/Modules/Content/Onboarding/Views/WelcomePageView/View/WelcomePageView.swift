//
//  WelcomePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct WelcomePageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<WelcomePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<WelcomePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressPageView()
            case .loaded:
                WelcomeContentPageView(viewModel)
            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onFirstAppear {
            viewModel.send(.viewFirstAppeared)
        }
        .onAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
