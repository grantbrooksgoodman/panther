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

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct NewChatPageView: View {
    // MARK: - Properties

    @StateObject private var observer: ViewObserver<NewChatPageObserver>
    @StateObject private var viewModel: ViewModel<NewChatPageReducer>

    // MARK: - Bindings

    private var contactSelectorSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingContactSelectorSheet,
            sendAction: { .isPresentingContactSelectorSheetChanged($0) }
        )
    }

    private var conversationBinding: Binding<Conversation> {
        viewModel.binding(
            for: \.conversation,
            sendAction: { .conversationChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<NewChatPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        NavigationView {
            VStack {
                ChatPageView(viewModel.conversation, configuration: .newChat)
                    .ignoresSafeArea(.keyboard)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(viewModel.navigationTitle)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .interactiveDismissDisabled()
            .background(Color.background)
            .toolbar {
                doneToolbarButton
            }
            .preferredStatusBarStyle(.lightContent)
        }
        .sheet(isPresented: contactSelectorSheetBinding) {
            ContactSelectorPageView(
                .init(
                    initialState: .init(contactSelectorSheetBinding),
                    reducer: ContactSelectorPageReducer()
                )
            )
        }
        .onFirstAppear {
            viewModel.send(.viewAppeared)
        }
    }

    private var doneToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Components.button(viewModel.doneToolbarButtonText) {
                viewModel.send(.doneToolbarButtonTapped)
            }
        }
    }
}
