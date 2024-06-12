//
//  RootNavigatorState.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct RootNavigatorState: NavigatorState {
    // MARK: - Types

    public enum ModalPaths: Paths {
        case conversations
        case onboarding
        case splash
    }

    public enum SeguePaths: Paths {}

    // MARK: - Properties

    public var onboarding: OnboardingNavigatorState = .init()

    public var modal: ModalPaths?
    public var stack: [SeguePaths] = []
}
