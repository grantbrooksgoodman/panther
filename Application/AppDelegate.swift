//
//  AppDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import UIKit

/* 3rd-party */
import AlertKit
import FirebaseCore
import Redux

@main
public final class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.breadcrumbs) private var breadcrumbs: Breadcrumbs
    @Dependency(\.build) private var build: Build
    @Dependency(\.networking.services.translation) private var hostedTranslationService: HostedTranslationService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSessionService.user) private var userSession: UserSessionService

    // MARK: - UIApplication

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        preInitialize()
        initializeBundle()

        /* Encapsulate further work here into setup functions. */

        return true
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {}

    // MARK: - Initialization + Setup

    private func preInitialize() {
        /* MARK: Defaults Keys & Logging Setup */

        RuntimeStorage.store(BuildConfig.languageCode, as: .languageCode)
        Logger.subscribe(to: BuildConfig.loggerDomainSubscriptions)

        @Persistent(.breadcrumbsCaptureEnabled) var breadcrumbsCaptureEnabled: Bool?
        @Persistent(.breadcrumbsCapturesAllViews) var breadcrumbsCapturesAllViews: Bool?
        if build.stage == .generalRelease {
            breadcrumbsCaptureEnabled = false
            breadcrumbsCapturesAllViews = nil
        } else if let breadcrumbsCaptureEnabled,
                  let breadcrumbsCapturesAllViews,
                  breadcrumbsCaptureEnabled {
            breadcrumbs.startCapture(uniqueViewsOnly: !breadcrumbsCapturesAllViews)
        }

        @Persistent(.hidesBuildInfoOverlay) var hidesBuildInfoOverlay: Bool?
        if hidesBuildInfoOverlay == nil {
            hidesBuildInfoOverlay = false
        }

        /* MARK: Developer Mode Setup */

        DevModeService.addStandardActions()
        DevModeService.addCustomActions()

        /* MARK: Theme Setup */

        @Persistent(.pendingThemeID) var pendingThemeID: String?
        @Persistent(.currentThemeID) var currentThemeID: String?

        if let themeID = pendingThemeID,
           let correspondingCase = AppTheme.allCases.first(where: { $0.theme.compressedHash == themeID }) {
            ThemeService.setTheme(correspondingCase.theme, checkStyle: false)
            pendingThemeID = nil
        } else if let currentThemeID,
                  let correspondingCase = AppTheme.allCases.first(where: { $0.theme.compressedHash == currentThemeID }) {
            ThemeService.setTheme(correspondingCase.theme, checkStyle: false)
        } else {
            ThemeService.setTheme(AppTheme.default.theme, checkStyle: false)
        }

        /* MARK: AlertKit Setup */

        let connectionAlertDelegate = ConnectionAlertDelegate()
        let expiryAlertDelegate = ExpiryAlertDelegate()
        let reportDelegate = ReportDelegate()
        let translationDelegate = TranslationDelegate()

        akCore.setLanguageCode(RuntimeStorage.languageCode)
        akCore.register(
            connectionAlertDelegate: connectionAlertDelegate,
            expiryAlertDelegate: expiryAlertDelegate,
            reportDelegate: reportDelegate,
            translationDelegate: translationDelegate
        )

        /* MARK: Localization Setup */

        let localizedStrings = Localization.localizedStrings
        guard !localizedStrings.isEmpty else {
            Logger.log(.init("Missing localized strings.", metadata: [self, #file, #function, #line]))
            return
        }

        let unsupportedLanguageCodes = ["ba", "ceb", "jv", "la", "mr", "ms", "udm"]
        let supportedLanguages = localizedStrings["language_codes"]?.filter { !unsupportedLanguageCodes.contains($0.key) }
        guard let supportedLanguages else {
            Logger.log(.init("No supported languages.", metadata: [self, #file, #function, #line]))
            return
        }

        RuntimeStorage.store(supportedLanguages, as: .languageCodeDictionary)
        guard let languageCodeDictionary = RuntimeStorage.languageCodeDictionary else { return }

        guard languageCodeDictionary[RuntimeStorage.languageCode] != nil else {
            RuntimeStorage.store("en", as: .languageCode)
            akCore.setLanguageCode("en")

            Logger.log(
                .init(
                    "Unsupported language code; reverting to English.",
                    metadata: [self, #file, #function, #line]
                )
            )
            return
        }
    }

    // MARK: - Bundle Initialization

    private func initializeBundle() {
        /* MARK: Firebase Setup */

        FirebaseApp.configure()

        /* MARK: AKTranslationDelegate Setup */

        akCore.register(translationDelegate: hostedTranslationService)

        /* MARK: MetadataService Key Resolution */

        Task {
            if let exception = await services.metadata.resolveValues() {
                Logger.log(exception)
            }
        }

        /* MARK: ReviewService Setup */

        services.review.incrementAppOpenCount()

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()

        /* MARK: UserSessionService Setup */

        Task {
            let setCurrentUserResult = await userSession.setCurrentUser()

            switch setCurrentUserResult {
            case .success:
                guard let currentUser = userSession.currentUser else {
                    Logger.log(.init("Failed to set current user.", metadata: [self, #file, #function, #line]))
                    return
                }

                if let exception = await currentUser.conversations?.setUsers() {
                    Logger.log(exception)
                }

            case let .failure(exception):
                Logger.log(exception)
            }
        }
    }

    // MARK: - UISceneSession

    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    public func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
