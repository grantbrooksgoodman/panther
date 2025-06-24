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

public final class UpdateService: AppSubsystem.Delegates.ForcedUpdateModalDelegate {
    // MARK: - Types

    public enum UpdateType {
        case forced
        case normal
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.currentCalendar) private var calendar: Calendar
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public static let shared = UpdateService()

    public let isForcedUpdateRequiredSubject = CurrentValueSubject<Bool?, Never>(nil)

    @Persistent(.buildNumberWhenLastForcedToUpdate) private var buildNumberWhenLastForcedToUpdate: Int?
    @Persistent(.relaunchesSinceLastPostponedUpdate) private var relaunchesSinceLastPostponedUpdate: Int?
    @Persistent(.firstPostponedUpdate) private var firstPostponedUpdate: Date?

    // MARK: - Computed Properties

    public var installButtonRedirectURL: URL? { metadataService.appShareLink }

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
    public func promptToUpdateIfNeeded() async -> Exception? {
        let checkForUpdatesResult = await checkForUpdates()

        switch checkForUpdatesResult {
        case let .success(updateType):
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

        case let .failure(exception):
            return exception
        }
    }

    private func checkForUpdates() async -> Callback<UpdateType?, Exception> {
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
            return .success(isUpdateAvailable ? .forced : nil)
        }

        guard hasUpdatedSinceLastForced else {
            return .success(isUpdateAvailable ? .forced : nil)
        }

        guard let firstPostponedUpdate else {
            return .success(isUpdateAvailable ? .normal : nil)
        }

        let interval = calendar.dateComponents(
            [.day],
            from: firstPostponedUpdate.comparator,
            to: Date.now.comparator
        )

        guard let daysPassed = interval.day else {
            return .success((isUpdateAvailable && shouldPrompt) ? .normal : nil)
        }

        if daysPassed < 0 {
            self.firstPostponedUpdate = nil
            relaunchesSinceLastPostponedUpdate = 0
            buildNumberWhenLastForcedToUpdate = nil
        }

        guard daysPassed >= 10 else {
            return .success((isUpdateAvailable && shouldPrompt) ? .normal : nil)
        }

        return .success(isUpdateAvailable ? .forced : nil)
    }

    // MARK: - Increment Relaunch Count

    public func incrementRelaunchCountIfNeeded() {
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
