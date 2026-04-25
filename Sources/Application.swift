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
/// ``AppSubsystem/delegates/register(buildInfoOverlayDotIndicatorColorDelegate:cacheDomainListDelegate:devModeAppActionDelegate:exceptionMetadataDelegate:forcedUpdateModalDelegate:localizedStringsDelegate:loggerDomainSubscriptionDelegate:permanentUserDefaultsKeyDelegate:uiThemeListDelegate:)``
/// call inside ``initialize()``. Pass `nil` for any delegate your
/// app does not need.
@MainActor
enum Application {
    // MARK: - Properties

    static var isInPrevaricationMode = false
    static var loadStartDate = Date.now

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
            localizedStringsDelegate: LocalizedStringKey.LocalizedStringsDelegate(),
            loggerDomainSubscriptionDelegate: LoggerDomain.SubscriptionDelegate(),
            permanentUserDefaultsKeyDelegate: UserDefaultsKey.PermanentKeyDelegate(),
            uiThemeListDelegate: UITheme.List()
        )

        AppSubsystem.initialize(
            appStoreBuildNumber: 33749,
            buildMilestone: buildMilestone,
            codeName: "Panther",
            finalName: "Hello",
            languageCode: Locale.systemLanguageCode,
            loggingEnabled: buildMilestone != .generalRelease
        )

        /* MARK: Networking Setup */

        Networking.initialize()
        Networking.config.registerActivityIndicatorDelegate(NetworkActivityIndicatorService())

        @Persistent(.hasRunOnce) var hasRunOnce: Bool?
        if UIDevice.isSimulator,
           hasRunOnce == nil {
            Networking.config.setEnvironment(.development)
            hasRunOnce = true
        } else if buildMilestone == .generalRelease {
            Networking.config.setEnvironment(.production)
        }

        /* MARK: Theme Setup */

        Task.delayed(by: .seconds(1)) { @MainActor in
            guard ThemeService.currentTheme == UITheme.default else { return }
            ThemeService.setTheme(UITheme.appDefault, checkStyle: false)
        }

        /* MARK: UIViewController Swizzling */

        UIViewController.swizzlePresent
        UIViewController.swizzleViewWillDisappear
    }
}
