//
//  ConversationsContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ConversationsContentPageView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<ConversationsPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ConversationsPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        VStack {
            NavigationView {
                List {
                    ForEach(viewModel.conversations, id: \.self) { conversation in
                        ConversationCellView(
                            .init(
                                initialState: .init(conversation),
                                reducer: ConversationCellReducer()
                            )
                        )
                    }
                }
                .background(Color.background)
                .listStyle(.plain)
                .navigationTitle(viewModel.strings.value(for: .navigationTitle))
                .refreshable {
                    viewModel.send(.pulledToRefresh)
                }
            }
            .id(viewModel.viewID)
        }
    }
}

private extension Array where Element == TranslationOutputMap {
    func value(for key: TranslatedLabelStringCollection.ConversationsPageViewStringKey) -> String {
        (first(where: { $0.key == .conversationsPageView(key) })?.value ?? key.rawValue).sanitized
    }
}
