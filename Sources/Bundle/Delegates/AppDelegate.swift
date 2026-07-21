//
//  AppDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import FirebaseAnalytics
import FirebaseCore
import FirebaseMessaging

/// The app's main entry point and application lifecycle delegate.
///
/// `AppDelegate` initializes the subsystem when the app
/// launches.
///
@main
final class AppDelegate: UIResponder, UIApplicationDelegate, @preconcurrency MessagingDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.firebaseMessaging) private var firebaseMessaging: Messaging
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiCacheInvalidationService) private var uiCacheInvalidationService: UICacheInvalidationService
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - UIApplication

    /// Performs one-time application setup at launch.
    ///
    /// This method calls ``Application/initialize()`` to register all
    /// app-level delegates and configure the subsystem before any
    /// scenes connect.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Application.initialize()
        setUpFirebaseAnalytics()
        setUpMessageOutboxRetry()
        setUpPushNotifications()
        services.analytics.logEvent(.openApp)
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        sessionStore.flushNow()
        uiCacheInvalidationService.refreshNotificationExtensionNameMap()
        services.analytics.logEvent(.terminateApp)
    }

    // MARK: - Set Up Firebase Analytics

    private func setUpFirebaseAnalytics() {
        Analytics.setAnalyticsCollectionEnabled(AnalyticsService.shouldEnableDataCollection)
    }

    // MARK: - Set Up Message Outbox Retry

    private func setUpMessageOutboxRetry() {
        @Dependency(\.build) var build: Build
        @Dependency(\.clientSession.outbox) var outbox: MessageOutboxService

        // Retry eligible entries on launch.
        Task { await outbox.retryAllEligible() }

        // Retry eligible entries when connectivity is restored.
        services.connectionStatus.addEffectUponConnectionChanged(
            id: .retryMessageOutbox
        ) {
            guard build.isOnline else { return }
            Task { await outbox.retryAllEligible() }
        }
    }

    // MARK: - Set Up Push Notifications

    private func setUpPushNotifications() {
        userNotificationCenter.delegate = self
        firebaseMessaging.delegate = self
        uiApplication.registerForRemoteNotifications()
    }

    // MARK: - UISceneSession

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        try? coreUtilities.eraseTemporaryDirectory()
    }

    // MARK: - MessagingDelegate Conformance

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        notificationCenter.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: ["token": fcmToken ?? ""]
        )

        services.pushToken.setCurrentToken(fcmToken)
    }

    // MARK: - UNUserNotificationCenterDelegate Conformance

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        do {
            return try await services
                .notification
                .respondToInAppNotification(notification)
        } catch {
            Logger.log(
                error,
                domain: .notifications
            )
        }

        return []
    }
}
