//
//  UpdateService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Combine
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem

final class UpdateService: AppSubsystem.Delegates.ForcedUpdateModalDelegate, @unchecked Sendable {
    // MARK: - Types

    enum UpdateType {
        case forced
        case normal
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.currentCalendar) private var calendar: Calendar
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    static let shared = UpdateService()

    let isForcedUpdateRequiredSubject = CurrentValueSubject<Bool?, Never>(nil)

    @Persistent(.buildNumberWhenLastForcedToUpdate) private var buildNumberWhenLastForcedToUpdate: Int?
    @Persistent(.relaunchesSinceLastPostponedUpdate) private var relaunchesSinceLastPostponedUpdate: Int?
    @Persistent(.firstPostponedUpdate) private var firstPostponedUpdate: Date?

    // MARK: - Computed Properties

    var installButtonRedirectURL: URL? {
        metadataService.appShareLink
    }

    private var hasUpdatedSinceLastForced: Bool {
        guard let buildNumberWhenLastForcedToUpdate else { return true }
        guard buildNumberWhenLastForcedToUpdate == build.buildNumber else {
            self.buildNumberWhenLastForcedToUpdate = nil
            return true
        }

        return false
    }

    // MARK: - Init

    private init() {}

    // MARK: - Check for Updates

    @discardableResult
    func promptToUpdateIfNeeded() async -> Exception? {
        do {
            let updateType = try await checkForUpdates()
            guard let updateType else { return nil }

            switch updateType {
            case .forced:
                firstPostponedUpdate = nil
                relaunchesSinceLastPostponedUpdate = 0
                buildNumberWhenLastForcedToUpdate = build.buildNumber
                isForcedUpdateRequiredSubject.send(true)
                return nil

            case .normal:
                return await presentUpdateCTA()
            }
        } catch {
            return error
        }
    }

    private func checkForUpdates() async throws(Exception) -> UpdateType? {
        guard let appStoreBuildNumber = metadataService.appStoreBuildNumber,
              let overrideForceUpdate = metadataService.shouldForceUpdate else {
            if let exception = await metadataService.resolveValues() {
                throw exception
            }

            return try await checkForUpdates()
        }

        let isUpdateAvailable = appStoreBuildNumber > build.buildNumber
        let shouldPrompt = (relaunchesSinceLastPostponedUpdate ?? 0) >= 3

        guard !overrideForceUpdate else {
            return isUpdateAvailable ? .forced : nil
        }

        guard hasUpdatedSinceLastForced else {
            return isUpdateAvailable ? .forced : nil
        }

        guard let firstPostponedUpdate else {
            return isUpdateAvailable ? .normal : nil
        }

        let interval = calendar.dateComponents(
            [.day],
            from: firstPostponedUpdate.comparator,
            to: Date.now.comparator
        )

        guard let daysPassed = interval.day else {
            return (isUpdateAvailable && shouldPrompt) ? .normal : nil
        }

        if daysPassed < 0 {
            self.firstPostponedUpdate = nil
            relaunchesSinceLastPostponedUpdate = 0
            buildNumberWhenLastForcedToUpdate = nil
        }

        guard daysPassed >= 10 else {
            return (isUpdateAvailable && shouldPrompt) ? .normal : nil
        }

        return isUpdateAvailable ? .forced : nil
    }

    // MARK: - Increment Relaunch Count

    func incrementRelaunchCountIfNeeded() {
        guard firstPostponedUpdate != nil else { return }
        relaunchesSinceLastPostponedUpdate = (relaunchesSinceLastPostponedUpdate ?? 0) + 1
    }

    // MARK: - Call to Action

    private func presentUpdateCTA() async -> Exception? {
        guard let appShareLink = metadataService.appShareLink else {
            if let exception = await metadataService.resolveValues() {
                return exception
            }

            return await presentUpdateCTA()
        }

        let updateAction: AKAction = .init("Update", style: .preferred) {
            Task { @MainActor in
                self.uiApplication.open(appShareLink)
            }

            self.firstPostponedUpdate = nil
            self.relaunchesSinceLastPostponedUpdate = 0
        }

        let cancelAction: AKAction = .init(
            Localized(.cancel).wrappedValue,
            style: .cancel
        ) {
            if self.firstPostponedUpdate == nil {
                self.firstPostponedUpdate = .now
            }

            self.relaunchesSinceLastPostponedUpdate = 0
        }

        await AKAlert(
            title: "Update Available",
            message: "A new version of ⌘\(build.finalName)⌘ is available in the ⌘App Store⌘. Would you like to update now?",
            actions: [updateAction, cancelAction]
        ).present(translating: [.actions([updateAction]), .message, .title])

        return nil
    }
}
