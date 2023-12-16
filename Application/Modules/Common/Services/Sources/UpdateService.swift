//
//  UpdateService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import Redux

public final class UpdateService {
    // MARK: - Types

    private struct UpdateResult {
        public let forceUpdate: Bool
        public let shouldPrompt: Bool
    }

    private enum UpdateType {
        case forced
        case normal
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.currentCalendar) private var calendar: Calendar
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var isPersistingForcedUpdateCTA = false

    @Persistent(.buildNumberWhenLastForcedToUpdate) private var buildNumberWhenLastForcedToUpdate: Int?
    @Persistent(.relaunchesSinceLastPostponedUpdate) private var relaunchesSinceLastPostponedUpdate: Int?
    @Persistent(.firstPostponedUpdate) private var firstPostponedUpdate: Date?

    // MARK: - Computed Properties

    private var hasUpdatedSinceLastForced: Bool {
        guard let buildNumberWhenLastForcedToUpdate else { return true }
        guard buildNumberWhenLastForcedToUpdate == build.buildNumber else {
            self.buildNumberWhenLastForcedToUpdate = nil
            return true
        }

        return false
    }

    // MARK: - Check for Updates

    @discardableResult
    public func promptToUpdateIfNeeded() async -> Exception? {
        let checkForUpdatesResult = await checkForUpdates()

        switch checkForUpdatesResult {
        case let .success(updateResult):
            guard updateResult.shouldPrompt else { return nil }
            return await presentCTA(for: updateResult.forceUpdate ? .forced : .normal)

        case let .failure(exception):
            return exception
        }
    }

    private func checkForUpdates() async -> Callback<UpdateResult, Exception> {
        guard let appStoreBuildNumber = metadataService.appStoreBuildNumber,
              let overrideForceUpdate = metadataService.shouldForceUpdate else {
            if let exception = await metadataService.resolveValues() {
                return .failure(exception)
            }

            return await checkForUpdates()
        }

        let isUpdateAvailable = appStoreBuildNumber > build.buildNumber
        let shouldPrompt = (relaunchesSinceLastPostponedUpdate ?? 0) >= 3

        guard !overrideForceUpdate else {
            return .success(.init(forceUpdate: true, shouldPrompt: isUpdateAvailable))
        }

        guard hasUpdatedSinceLastForced else {
            return .success(.init(forceUpdate: true, shouldPrompt: isUpdateAvailable))
        }

        guard let firstPostponedUpdate else {
            return .success(.init(forceUpdate: false, shouldPrompt: isUpdateAvailable))
        }

        let interval = calendar.dateComponents(
            [.day],
            from: firstPostponedUpdate.comparator,
            to: Date().comparator
        )

        guard let daysPassed = interval.day else {
            return .success(.init(forceUpdate: false, shouldPrompt: isUpdateAvailable && shouldPrompt))
        }

        if daysPassed < 0 {
            self.firstPostponedUpdate = nil
            relaunchesSinceLastPostponedUpdate = 0
            buildNumberWhenLastForcedToUpdate = nil
        }

        guard daysPassed >= 10 else {
            return .success(.init(forceUpdate: false, shouldPrompt: isUpdateAvailable && shouldPrompt))
        }

        return .success(.init(forceUpdate: true, shouldPrompt: isUpdateAvailable))
    }

    // MARK: - Increment Relaunch Count

    public func incrementRelaunchCountIfNeeded() {
        guard firstPostponedUpdate != nil else { return }
        relaunchesSinceLastPostponedUpdate = (relaunchesSinceLastPostponedUpdate ?? 0) + 1
    }

    // MARK: - Call to Action

    private func presentCTA(for type: UpdateType) async -> Exception? {
        guard let appShareLink = metadataService.appShareLink else {
            if let exception = await metadataService.resolveValues() {
                return exception
            }

            return await presentCTA(for: type)
        }

        switch type {
        case .forced:
            presentForcedUpdateCTA(appShareLink)

        case .normal:
            presentNormalUpdateCTA(appShareLink)
        }

        return nil
    }

    private func presentForcedUpdateCTA(_ url: URL) {
        isPersistingForcedUpdateCTA = true

        Task { @MainActor in
            uiApplication.keyWindow?.isUserInteractionEnabled = true
        }

        let message = "This version of *\(build.finalName)* is no longer supported. To continue, please download and install the most recent update."

        AKAlert(
            title: "Update Required",
            message: message,
            actions: [AKAction(title: "Update", style: .preferred)],
            showsCancelButton: build.developerModeEnabled || build.stage != .generalRelease
        ).present { actionID in
            self.firstPostponedUpdate = nil
            self.relaunchesSinceLastPostponedUpdate = 0

            guard actionID != -1 else {
                self.isPersistingForcedUpdateCTA = false
                return
            }

            self.uiApplication.keyWindow?.isUserInteractionEnabled = false
            self.uiApplication.open(url)

            self.buildNumberWhenLastForcedToUpdate = self.build.buildNumber
            self.presentForcedUpdateCTA(url)
        }
    }

    private func presentNormalUpdateCTA(_ url: URL) {
        let message = "A new version of *\(build.finalName)* is available in the *App Store*. Would you like to update now?"

        AKAlert(
            title: "Update Available",
            message: message,
            actions: [.init(title: "Update", style: .preferred)],
            cancelButtonTitle: "Later"
        ).present { actionID in
            guard actionID != -1 else {
                if self.firstPostponedUpdate == nil {
                    self.firstPostponedUpdate = Date()
                }

                self.relaunchesSinceLastPostponedUpdate = 0
                return
            }

            self.uiApplication.open(url)
            self.firstPostponedUpdate = nil
            self.relaunchesSinceLastPostponedUpdate = 0
        }
    }
}
