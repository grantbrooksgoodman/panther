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
            appStoreReleaseVersion: 3,
            buildMilestone: .beta,
            codeName: "Panther",
            dmyFirstCompileDateString: "11112023",
            finalName: "Hello",
            languageCode: Locale.systemLanguageCode,
            loggingEnabled: true,
            timebombActive: true
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
