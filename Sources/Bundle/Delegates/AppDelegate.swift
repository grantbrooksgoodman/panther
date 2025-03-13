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

@main
public final class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.firebaseMessaging) private var firebaseMessaging: Messaging
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - UIApplication

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Application.initialize()
        setUpFirebaseAnalytics()
        setUpPushNotifications()
        services.analytics.logEvent(.openApp)
        return true
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        userSession.persistOfflineCurrentUser()
        services.analytics.logEvent(.terminateApp)
    }

    // MARK: - Set Up Firebase Analytics

    private func setUpFirebaseAnalytics() {
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    // MARK: - Set Up Push Notifications

    private func setUpPushNotifications() {
        userNotificationCenter.delegate = self
        firebaseMessaging.delegate = self
        uiApplication.registerForRemoteNotifications()
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
        coreUtilities.eraseTemporaryDirectory()
    }

    // MARK: - MessagingDelegate Conformance

    public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        notificationCenter.post(name: Notification.Name("FCMToken"), object: nil, userInfo: ["token": fcmToken ?? ""])
        services.pushToken.setCurrentToken(fcmToken)
    }

    // MARK: - UNUserNotificationCenterDelegate Conformance

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let respondToInAppNotificationResult = await services.notification.respondToInAppNotification(notification)

        switch respondToInAppNotificationResult {
        case let .success(presentationOptions):
            return presentationOptions

        case let .failure(exception):
            Logger.log(exception, domain: .notifications)
            return []
        }
    }
}
