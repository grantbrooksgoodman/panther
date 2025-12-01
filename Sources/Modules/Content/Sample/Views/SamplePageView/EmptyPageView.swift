//
//  EmptyPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

struct EmptyPageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<SamplePageReducer>

    // MARK: - Init

    init(_ viewModel: ViewModel<SamplePageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    var body: some View {
        VStack {
            Text("Hello world")
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
