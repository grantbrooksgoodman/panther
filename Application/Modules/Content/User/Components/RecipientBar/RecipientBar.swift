//
//  RecipientBar.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct RecipientBar: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.RecipientBar
    private typealias Floats = AppConstants.CGFloats.RecipientBar

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<RecipientBarReducer>

    // MARK: - Bindings

    private var textFieldTextBinding: Binding<String> {
        viewModel.binding(
            for: \.textFieldText,
            sendAction: { .textFieldTextChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<RecipientBarReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        VStack {
            Divider()
            Spacer()

            HStack {
                Text("To:")

                TextField(text: textFieldTextBinding) {
                    EmptyView()
                }
            }
            .padding(.horizontal, Floats.hStackHorizontalPadding)

            Spacer()
            Divider()
        }
        .frame(maxWidth: .infinity, maxHeight: Floats.frameMaxHeight)
        .background(Colors.background)
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }
}
