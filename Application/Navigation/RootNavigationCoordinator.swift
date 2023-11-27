//
//  RootNavigationCoordinator.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum RootPage: CaseIterable {
    // MARK: - Cases

    case sample
    case onboarding(OnboardingPage)

    // MARK: - Properties

    public static var allCases: [RootPage] {
        [
            .sample,
            .onboarding(.welcome),
        ]
    }

    public var rawValue: String {
        switch self {
        case .sample:
            return "sample"

        case let .onboarding(page):
            return "onboarding: \(page.rawValue)"
        }
    }
}

public final class RootNavigationCoordinator: ObservableObject {
    // MARK: - Properties

    @Published public private(set) var page: RootPage = .onboarding(.welcome)

    // MARK: - Methods

    public func setPage(_ page: RootPage) {
        self.page = page
    }
}
