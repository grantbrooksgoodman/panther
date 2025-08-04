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

public enum Application {
    // MARK: - Properties

    public static var isInPrevaricationMode = false
    public static var loadStartDate: Date = .now

    private static var buildMilestone: Build.Milestone {
        @Persistent(.buildMilestoneString) var persistedMilestoneString: String?
        var buildMilestone: Build.Milestone = UIDevice.isSimulator ? .beta : .generalRelease
        if let persistedMilestoneString { buildMilestone = .init(rawValue: persistedMilestoneString) ?? buildMilestone }
        persistedMilestoneString = buildMilestone.rawValue
        return buildMilestone
    }

    // MARK: - Initialize

    @MainActor
    public static func initialize() {
        // MARK: - App Subsystem Setup

        AppSubsystem.delegates.register(
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
            appStoreBuildNumber: 29733,
            buildMilestone: buildMilestone,
            codeName: "Panther",
            dmyFirstCompileDateString: "11112023",
            finalName: "Hello",
            languageCode: Locale.systemLanguageCode,
            loggingEnabled: buildMilestone != .generalRelease
        )

        // MARK: - Networking Setup

        Networking.initialize()
        Networking.config.registerActivityIndicatorDelegate(NetworkActivityIndicatorService())

        @Persistent(.hasRunOnce) var hasRunOnce: Bool?
        if UIDevice.isSimulator,
           hasRunOnce == nil {
            if !UIApplication.isFullyV26Compatible { hasRunOnce = true }
            Networking.config.setEnvironment(.development)
        } else if buildMilestone == .generalRelease { // TODO: Fix to make Production default.
            Networking.config.setEnvironment(.production)
        }

        // MARK: - Theme Setup

        Task.delayed(by: .seconds(1)) {
            guard ThemeService.currentTheme == UITheme.default else { return }
            ThemeService.setTheme(UITheme.appDefault, checkStyle: false)
        }

        // MARK: - v26 Features Setup

        guard UIApplication.isFullyV26Compatible,
              hasRunOnce == nil else { return }

        @Persistent(.isGlassTintingEnabled) var isGlassTintingEnabled: Bool?
        @Persistent(.v26FeaturesEnabled) var v26FeaturesEnabled: Bool?

        if isGlassTintingEnabled == nil { isGlassTintingEnabled = true }
        if v26FeaturesEnabled == nil { v26FeaturesEnabled = true }
        hasRunOnce = true
    }
}
