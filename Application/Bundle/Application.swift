//
//  Application.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 10/09/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking

public enum Application {
    // MARK: - Properties

    public static var isInPrevaricationMode = false

    private static var buildMilestone: Build.Milestone {
        @Persistent(.buildMilestoneString) var persistedMilestoneString: String?
        var buildMilestone: Build.Milestone = .generalRelease
        if let persistedMilestoneString { buildMilestone = .init(rawValue: persistedMilestoneString) ?? buildMilestone }
        persistedMilestoneString = buildMilestone.rawValue
        return buildMilestone
    }

    // MARK: - Initialize

    @MainActor
    public static func initialize() {
        // MARK: - App Subsystem Setup

        AppSubsystem.delegates.register(
            appThemeListDelegate: AppTheme.List(),
            buildInfoOverlayDotIndicatorColorDelegate: BuildInfoOverlay.DotIndicatorColorDelegate(),
            cacheDomainListDelegate: CacheDomain.List(),
            devModeAppActionDelegate: DevModeAction.AppActions(),
            exceptionMetadataDelegate: AppException.ExceptionMetadataDelegate(),
            localizedStringsDelegate: Localization.LocalizedStringsDelegate()
        )

        AppSubsystem.initialize(
            appStoreReleaseVersion: 4,
            buildMilestone: buildMilestone,
            codeName: "Panther",
            dmyFirstCompileDateString: "11112023",
            finalName: "Hello",
            languageCode: Locale.systemLanguageCode,
            loggingEnabled: buildMilestone != .generalRelease,
            timebombActive: buildMilestone != .generalRelease
        )

        // MARK: - Localization & Logging Setup

        Localization.initialize()

        Logger.setDomainsExcludedFromSessionRecord(LoggerDomain.domainsExcludedFromSessionRecord)
        Logger.subscribe(to: LoggerDomain.subscribedDomains)

        // MARK: - Navigation Setup

        let navigationCoordinator: NavigationCoordinator<RootNavigationService> = .init(
            .init(modal: .splash),
            navigating: RootNavigationService()
        )

        NavigationCoordinatorResolver.shared.store(navigationCoordinator)

        // MARK: - Networking Setup

        Networking.initialize()
        Networking.config.registerActivityIndicatorDelegate(NetworkActivityIndicatorService())
        if buildMilestone == .generalRelease { Networking.config.setEnvironment(.production) } // TODO: Fix to make Production default.

        // MARK: - Theme Setup

        Task.delayed(by: .seconds(1)) {
            guard ThemeService.currentTheme == AppTheme.default.theme else { return }
            ThemeService.setTheme(AppTheme.appDefault.theme, checkStyle: false)
        }
    }
}

private extension BuildInfoOverlay {
    struct DotIndicatorColorDelegate: AppSubsystem.Delegates.BuildInfoOverlayDotIndicatorColorDelegate {
        public var developerModeIndicatorDotColor: Color {
            switch Networking.config.environment {
            case .development: return .green
            case .production: return .red
            case .staging: return .orange
            }
        }
    }
}

public extension Persistent {
    convenience init(_ applicationKey: UserDefaultsKey.ApplicationDefaultsKey) {
        self.init(.application(applicationKey))
    }
}

public extension UserDefaultsKey {
    enum ApplicationDefaultsKey: String {
        case buildMilestoneString
    }
}
