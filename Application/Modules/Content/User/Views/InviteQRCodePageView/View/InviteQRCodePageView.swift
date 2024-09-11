//
//  InviteQRCodePageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct InviteQRCodePageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<InviteQRCodePageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<InviteQRCodePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        Group {
            switch viewModel.viewState {
            case .loading:
                ProgressPageView()
            case .loaded:
                InviteQRCodeContentPageView(viewModel)
            case let .error(exception):
                FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
            }
        }
        .preferredStatusBarStyle(.lightContent)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
