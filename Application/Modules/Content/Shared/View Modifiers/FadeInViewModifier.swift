//
//  FadeInViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import CoreArchitecture

private struct FadeInViewModifier: ViewModifier {
    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD

    // MARK: - Properties

    private let duration: Duration
    private let delay: Duration
    @State private var opacity: CGFloat = 0

    // MARK: - Init

    public init(_ duration: Duration, delay: Duration) {
        self.duration = duration
        self.delay = delay
    }

    // MARK: - Body

    public func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                func animateOpacity() { withAnimation(.easeIn(duration: duration.milliseconds / 1000)) { opacity = 1 } }
                guard delay != .zero else {
                    animateOpacity()
                    return
                }
                coreGCD.after(delay) { animateOpacity() }
            }
    }
}

public extension View {
    func fadeIn(_ duration: Duration = .milliseconds(500), delay: Duration = .zero) -> some View {
        modifier(FadeInViewModifier(duration, delay: delay))
    }
}
