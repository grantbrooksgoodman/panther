//
//  SelectLanguagePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import CoreArchitecture

public struct SelectLanguagePageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<SelectLanguagePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<SelectLanguagePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressPageView()
            case .loaded:
                SelectLanguageContentPageView(viewModel)
            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
