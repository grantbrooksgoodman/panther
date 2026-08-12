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

/// Use ``ReviewService`` to request App Store reviews at appropriate moments.
///
/// Review prompts are limited to at most one per build, on qualifying app launches.
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

    /// Increments the persisted count of app launches.
    func incrementAppOpenCount() {
        appOpenCount = (appOpenCount ?? 0) + 1
    }

    /// Requests an App Store review if the necessary conditions are met.
    ///
    /// A review may be requested once per build, when the app launch count reaches a
    /// qualifying value. If a review was already requested for the current build, or the
    /// launch count does not qualify, this method does nothing.
    @MainActor
    func promptToReview() {
        guard canPromptToReview,
              let windowScene = uiApplication.mainWindow?.windowScene else { return }
        AppStore.requestReview(in: windowScene)

        @Persistent(.lastRequestedReviewForBuildNumber) var lastRequestedReviewForBuildNumber: Int?
        lastRequestedReviewForBuildNumber = build.buildNumber
    }
}
