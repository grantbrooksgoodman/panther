//
//  Application.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/09/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/* 3rd-party */
import MessageKit

/// The app's bootstrap configuration.
///
/// `Application` centralizes the two-step process required to
/// initialize the ``AppSubsystem`` framework: registering delegates and
/// calling ``AppSubsystem/initialize(appStoreBuildNumber:buildMilestone:codeName:finalName:languageCode:loggingEnabled:)``.
/// ``AppDelegate`` calls ``initialize()`` once at launch – no other
/// call site is needed.
///
/// To customize framework behavior, supply your own delegate
/// conformances in the
/// ``AppSubsystem/delegates/register(buildInfoOverlayDotIndicatorColorDelegate:cacheDomainListDelegate:devModeAppActionDelegate:exceptionMetadataDelegate:forcedUpdateModalDelegate:loggerDomainSubscriptionDelegate:permanentPersistentStorageKeyDelegate:uiThemeListDelegate:)``
/// call inside ``initialize()``. Pass `nil` for any delegate your
/// app does not need.
@MainActor
enum Application {
    // MARK: - Properties

    static var isInPrevaricationMode = false
    static var loadStartDate = Date.now

    // MARK: - Computed Properties

    static var isInStagingMode: Bool {
        @Dependency(\.mainBundle) var mainBundle: Bundle
        @Persistent(.isInStagingMode) var persistedValue: Bool?
        guard mainBundle.containsStagingAssets else {
            persistedValue = nil
            return false
        }

        return persistedValue ?? false
    }

    private static var buildMilestone: Build.Milestone {
        @Persistent(.buildMilestoneString) var persistedMilestoneString: String?
        var buildMilestone: Build.Milestone = UIDevice.isSimulator ? .beta : .generalRelease
        if let persistedMilestoneString { buildMilestone = .init(rawValue: persistedMilestoneString) ?? buildMilestone }
        persistedMilestoneString = buildMilestone.rawValue
        return buildMilestone
    }

    // MARK: - Initialize

    /// Registers delegates and initializes the ``AppSubsystem``
    /// framework.
    ///
    /// This method performs two operations in sequence:
    ///
    /// 1. **Delegate registration.** Each delegate customizes a
    ///    specific aspect of ``AppSubsystem`` – caching policy,
    ///    developer-mode actions, exception metadata, localized
    ///    strings, logging, theming, and more. Delegates are defined
    ///    in the `Bundle` directory and conform to protocols declared
    ///    by ``AppSubsystem``.
    /// 2. **Framework initialization.** Configures build metadata
    ///    and enables all subsystem services. This call may only
    ///    occur once per launch; a second call triggers a fatal
    ///    error.
    ///
    /// Update the build metadata parameters – `appStoreBuildNumber`,
    /// `buildMilestone`, `codeName`, and `finalName` – to match
    /// your app's current release cycle.
    ///
    /// - Important: This method must be called exactly once, before
    ///   any other ``AppSubsystem`` API is used. ``AppDelegate``
    ///   calls it in
    ///   ``AppDelegate/application(_:didFinishLaunchingWithOptions:)``.
    static func initialize() {
        /* MARK: App Subsystem Setup */

        AppSubsystem.delegates.register(
            breadcrumbsCaptureDelegate: BreadcrumbsCaptureService.shared,
            buildInfoOverlayDotIndicatorColorDelegate: Networking.BuildInfoOverlayDotIndicatorColorDelegate.shared,
            cacheDomainListDelegate: CacheDomain.List(),
            devModeAppActionDelegate: DevModeAction.AppActions(),
            exceptionMetadataDelegate: AppException.ExceptionMetadataDelegate(),
            forcedUpdateModalDelegate: UpdateService.shared,
            loggerDomainSubscriptionDelegate: LoggerDomain.SubscriptionDelegate(),
            permanentPersistentStorageKeyDelegate: PersistentStorageKey.PermanentKeyDelegate(),
            uiThemeListDelegate: UITheme.List()
        )

        AppSubsystem.initialize(
            appStoreBuildNumber: 37186,
            buildMilestone: buildMilestone,
            codeName: "Panther",
            finalName: "Hello",
            languageCode: Locale.systemLanguageCode,
            loggingEnabled: buildMilestone != .generalRelease
        )

        Logger.log(
            "Application launched.",
            sender: self
        )

        /* MARK: Networking Setup */

        Networking.initialize()
        Networking.config.registerActivityIndicatorDelegate(
            NetworkActivityIndicatorService()
        )

        Networking.config.setNetworkHealthConfiguration(
            .init(
                probeConfiguration: Networking.probeConfiguration
            )
        )

        @Dependency(\.networking) var networking: NetworkServices
        networking.database.prewarm()
        networking.storage.prewarm()

        @Persistent(.hasRunOnce) var hasRunOnce: Bool?
        if UIDevice.isSimulator,
           hasRunOnce == nil {
            @Persistent(.init("breadcrumbsCaptureEnabled")) var breadcrumbsCaptureEnabled: Bool?
            @Persistent(.init("breadcrumbsCaptureSavesToPhotos")) var breadcrumbsCaptureSavesToPhotos: Bool?

            @Dependency(\.commonServices.breadcrumbsCapture) var breadcrumbsCaptureService: BreadcrumbsCaptureService

            breadcrumbsCaptureEnabled = true
            breadcrumbsCaptureSavesToPhotos = true
            try? breadcrumbsCaptureService.startCapture()

            Networking.config.setEnvironment(.development)
            hasRunOnce = true
        } else if buildMilestone == .generalRelease {
            Networking.config.setEnvironment(.production)
        }

        /* MARK: Text-to-Speech Setup */

        // The first speech-daemon query is a seconds-slow XPC call
        // that must never run on the maim thread or the cooperative pool;
        // prewarm both inventories onto their own background queues so the
        // send and view-construction paths never block on the daemon.
        @Dependency(\.commonServices.audio) var audioService: AudioService
        audioService.textToSpeech.prewarmVoiceInventory()
        audioService.transcription.prewarmSupportInventory()

        // A set in-flight flag means the previous process terminated
        // mid-synthesis; the speech daemon may be wedged, so degrade
        // synthesis to serial traffic for the first window.
        @Persistent(.ttsSynthesisInFlight) var ttsSynthesisInFlight: Bool?
        if ttsSynthesisInFlight == true {
            Task { await audioService.textToSpeech.degradeSynthesisAfterUncleanLaunch() }
        }

        /* MARK: Dependency Prewarm */

        // Resolve select main-actor-isolated dependencies eagerly,
        // on the main actor, so their first resolution can never race
        // onto a background thread. See `MainActorIsolated`.
        @Dependency(\.commonServices) var commonServices: CommonServices
        @Dependency(\.uiCacheInvalidationService) var uiCacheInvalidationService: UICacheInvalidationService

        _ = commonServices
        _ = uiCacheInvalidationService

        /* MARK: Theme Setup */

        Task.delayed(by: .seconds(1)) { @MainActor in
            guard ThemeService.currentTheme == UITheme.default else { return }
            ThemeService.setTheme(UITheme.appDefault, checkStyle: false)
        }

        /* MARK: Swizzling */

        MessageContentCell.swizzleApply
        UIViewController.swizzlePresent
        UIViewController.swizzleViewWillDisappear
    }
}

private extension Networking {
    static let probeConfiguration: NetworkHealthProbeConfiguration? = {
        guard let url = URL(string: "https://www.apple.com") else { return nil }
        return NetworkHealthProbeConfiguration(url: url)
    }()
}
