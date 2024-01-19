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

    case conversations
    case sample
    case splash
    case onboarding(OnboardingPage)

    // MARK: - Properties

    public static var allCases: [RootPage] {
        [
            .conversations,
            .sample,
            .splash,
            .onboarding(.welcome),
            .onboarding(.selectLanguage),
            .onboarding(.verifyNumber),
            .onboarding(.authCode),
            .onboarding(.permission),
        ]
    }

    public var rawValue: String {
        switch self {
        case .conversations:
            return "conversations"

        case .sample:
            return "sample"

        case .splash:
            return "splash"

        case let .onboarding(page):
            return "onboarding: \(page.rawValue)"
        }
    }
}

public final class RootNavigationCoordinator: ObservableObject {
    // MARK: - Properties

    @Published public private(set) var page: RootPage = .splash

    // MARK: - Methods

    public func setPage(_ page: RootPage) {
        self.page = page
    }
}
