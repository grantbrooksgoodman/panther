//
//  ConversationsPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct ConversationsPageView: View {
    // MARK: - Properties

    @StateObject private var observer: ViewObserver<ConversationsPageObserver>
    @StateObject private var viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressPageView()
            case .loaded:
                ConversationsContentPageView(viewModel)
            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
