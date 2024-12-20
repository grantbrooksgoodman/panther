//
//  PenPalsPermissionPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/12/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct PenPalsPermissionPageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<PenPalsPermissionPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<PenPalsPermissionPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            Group {
                switch viewModel.viewState {
                case .loading:
                    ProgressPageView(backgroundColor: ThemeService.isDarkModeActive ? Color.listViewBackground : .white)
                case .loaded:
                    PenPalsPermissionContentPageView(viewModel)
                case let .error(exception):
                    FailurePageView(.init(initialState: .init(exception), reducer: FailurePageReducer()))
                }
            }
            .background(ThemeService.isDarkModeActive ? Color.listViewBackground : .white)
            .interactiveDismissDisabled()
            .preferredStatusBarStyle(.lightContent, restoreOnDisappear: true)
            .onFirstAppear {
                viewModel.send(.viewAppeared)
            }
        }
    }
}
