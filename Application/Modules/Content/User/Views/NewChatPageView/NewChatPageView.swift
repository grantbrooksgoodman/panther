//
//  NewChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct NewChatPageView: View {
    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<NewChatPageReducer>

    // MARK: - Bindings

    private var conversationBinding: Binding<Conversation> {
        viewModel.binding(
            for: \.conversation,
            sendAction: { .conversationChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<NewChatPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    // MARK: - View

    public var body: some View {
        NavigationView {
            VStack {
                ChatPageView(viewModel.conversation, forPreview: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .interactiveDismissDisabled()
            .background(Color.background)
            .toolbar {
                doneToolbarButton
            }
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    private var doneToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            Button(viewModel.doneToolbarButtonText) {
                viewModel.send(.isPresentedChanged(false))
            }
            .foregroundStyle(Color.accent)
        }
    }
}
