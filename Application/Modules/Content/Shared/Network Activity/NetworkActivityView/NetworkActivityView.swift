//
//  NetworkActivityView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct NetworkActivityView: View {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.NetworkActivityView
    private typealias Floats = AppConstants.CGFloats.NetworkActivityView

    // MARK: - Properties

    @StateObject private var viewModel: ViewModel<NetworkActivityReducer>
    @StateObject private var observer: ViewObserver<NetworkActivityObserver>

    // MARK: - Init

    public init(_ viewModel: ViewModel<NetworkActivityReducer>) {
        _viewModel = .init(wrappedValue: viewModel)
        _observer = .init(wrappedValue: .init(.init(viewModel)))
    }

    // MARK: - View

    public var body: some View {
        Circle()
            .foregroundStyle(Color.accent)
            .padding(.all, Floats.padding)
            .frame(
                width: Floats.frameWidth,
                height: Floats.frameHeight
            )
            .overlay {
                ProgressView()
                    .tint(Colors.progressViewTint)
            }
            .offset(y: viewModel.yOffset)
            .opacity(viewModel.isHidden ? 0 : 1)
            .animation(.spring(), value: viewModel.yOffset)
    }
}
