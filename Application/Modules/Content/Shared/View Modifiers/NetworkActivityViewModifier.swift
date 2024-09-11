//
//  NetworkActivityViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

private struct NetworkActivityViewModifier: ViewModifier {
    public func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                NetworkActivityView(
                    .init(
                        initialState: .init(),
                        reducer: NetworkActivityReducer()
                    )
                )
                Spacer()
            }
        }
    }
}

public extension View {
    func showsNetworkActivity() -> some View {
        modifier(NetworkActivityViewModifier())
    }
}
