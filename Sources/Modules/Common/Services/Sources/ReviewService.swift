//
//  ReviewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import StoreKit

/* Proprietary */
import AppSubsystem

struct ReviewService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    @Persistent(.appOpenCount) private var appOpenCount: Int?

    // MARK: - Computed Properties

    private var canPromptToReview: Bool {
        guard lastRequestedReviewForBuildNumber != build.buildNumber,
              appOpenCount == 10 || appOpenCount == 50 || (appOpenCount ?? 0) % 100 == 0 else { return false }
        return true
    }

    private var lastRequestedReviewForBuildNumber: Int {
        @Persistent(.lastRequestedReviewForBuildNumber) var defaultsValue: Int?
        guard let defaultsValue else {
            let buildNumber = build.buildNumber - 1
            defaultsValue = buildNumber < 0 ? 0 : buildNumber
            return buildNumber
        }

        return defaultsValue
    }

    // MARK: - Methods

    func incrementAppOpenCount() {
        appOpenCount = (appOpenCount ?? 0) + 1
    }

    @MainActor
    func promptToReview() {
        guard canPromptToReview,
              let windowScene = uiApplication.mainWindow?.windowScene else { return }
        SKStoreReviewController.requestReview(in: windowScene)

        @Persistent(.lastRequestedReviewForBuildNumber) var lastRequestedReviewForBuildNumber: Int?
        lastRequestedReviewForBuildNumber = build.buildNumber
    }
}
