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

    @StateObject var viewModel: ViewModel<NewChatPageReducer>

    @StateObject private var observer: ViewObserver<NewChatPageObserver>

    // MARK: - Bindings

    private var contactSelectorSheetBinding: Binding<Bool> {
        viewModel.binding(
            for: \.isPresentingContactSelectorSheet,
            sendAction: { .isPresentingContactSelectorSheetChanged($0) }
        )
    }

    // MARK: - Init

    public init(_ viewModel: ViewModel<NewChatPageReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            VStack {
                ChatPageView(viewModel.conversation, configuration: .newChat)
                    .ignoresSafeArea(.keyboard)
                    .background(Color.background)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .header(
                leftItem: viewModel.shouldShowPenPalsToolbarButton ? headerLeftItem : nil,
                headerCenterItem,
                rightItem: headerRightItem,
                attributes: .init(
                    showsDivider: viewModel.shouldUseBoldDoneToolbarButton,
                    sizeClass: .sheet
                )
            )
            .foregroundStyle(Color.background)
            .interactiveDismissDisabled()
            .background(Color.background)
            .preferredStatusBarStyle(.lightContent, restoreOnDisappear: !Application.isInPrevaricationMode)
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
    }
}
