//
//  RootView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct RootView: View {
    // MARK: - Properties

    @ObservedDependency(\.rootNavigationCoordinator) private var navigationCoordinator: RootNavigationCoordinator

    // MARK: - View

    public var body: some View {
        GeometryReader { proxy in
            Group {
                switch navigationCoordinator.page {
                case .sample:
                    withTransition { SamplePageView(.init(initialState: .init(), reducer: SamplePageReducer())) }
                }
            }
            .environment(\.keyWindowSize, proxy.size)
        }
    }
}

private extension View {
    func withTransition(_ view: () -> some View) -> some View {
        view()
            .transition(AnyTransition.opacity.animation(.easeIn(duration: 0.2)))
            .zIndex(1)
    }
}
