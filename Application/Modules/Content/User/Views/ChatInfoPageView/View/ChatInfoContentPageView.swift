//
//  ChatInfoContentPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ChatInfoContentPageView: View {
    // MARK: - Properties

    @ObservedObject private var viewModel: ViewModel<ChatInfoPageReducer>

    // MARK: - Init

    public init(_ viewModel: ViewModel<ChatInfoPageReducer>) {
        self.viewModel = viewModel
    }

    // MARK: - View

    public var body: some View {
        ThemedView {
            VStack {
                Text("Hello world")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.background)
        }
        .header(isThemed: true)
        .preferredStatusBarStyle(.lightContent)
    }
}
