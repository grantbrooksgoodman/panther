//
//  AnalyticsService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

/* 3rd-party */
import FirebaseAnalytics

public struct AnalyticsService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.uiApplication.keyViewController?.leafViewController) private var leafViewController: UIViewController?
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Types

    public enum AnalyticsEvent: String {
        /* MARK: Cases */

        case accessChat
        case accessNewChatPage

        case clearCaches
        case closeApp
        case createNewConversation

        case deleteAccount
        case deleteConversation
        case dismissNewChatPage

        case invite

        case logIn
        case logOut

        case openApp

        case sendAudioMessage
        case sendMediaMessage
        case sendTextMessage
        case signUp

        case terminateApp
        case touchUiElement

        case viewAlternate

        /* MARK: Properties */

        public var name: String {
            rawValue.snakeCased
        }
    }

    // MARK: - Computed Properties

    public static var shouldEnableDataCollection: Bool {
        @Dependency(\.build) var build: Build

        if !CommandLine.arguments.containsAllStrings(in: ["-FIRAnalyticsDebugEnabled", "-FIRDebugEnabled"]) {
            guard Networking.config.environment == .production,
                  build.milestone == .generalRelease else { return false }
            return true
        }

        return true
    }

    // MARK: - Properties

    private var commonParams: [String: String] {
        var parameters = [
            "build_sku": build.buildSKU,
            "bundle_revision": "\(build.bundleRevision) (\(build.revisionBuildNumber))",
            "bundle_version": "\(build.bundleVersion) (\(build.buildNumber)\(build.milestone.shortString))",
            "connection_status": build.isOnline ? "online" : "offline",
            "device_model": "\(SystemInformation.modelName) (\(SystemInformation.modelCode.lowercased()))",
            "language_code": RuntimeStorage.languageCode,
            "os_version": SystemInformation.osVersion.lowercased(),
            "project_id": build.projectID,
            "timestamp": dateFormatter.string(from: .now),
        ]

        if let currentUserID = User.currentUserID {
            parameters["current_user_id"] = currentUserID
        }

        if let leafViewController {
            parameters["view_id"] = leafViewController.descriptor
        }

        return parameters
    }

    // MARK: - Log Event

    public func logEvent(_ event: AnalyticsEvent, userInfo: [String: String]? = nil) {
        Task { @MainActor in
            guard AnalyticsService.shouldEnableDataCollection else { return }

            var parameters = commonParams
            if let userInfo {
                userInfo.forEach { parameters[$0] = $1 }
            }

            for (key, value) in parameters {
                guard value.count > 40 else { continue }
                var clippedValue = value
                while clippedValue.count > 40 { clippedValue = clippedValue.dropSuffix() }
                parameters[key] = clippedValue
            }

            Logger.log(
                .init(
                    "Logging analytics event \"\(event.name)\".",
                    isReportable: false,
                    userInfo: parameters,
                    metadata: .init(sender: self)
                ),
                domain: .analytics
            )

            Analytics.logEvent(event.name, parameters: parameters)

            guard let currentUser,
                  ["15555555555", "18888888888"].contains(currentUser.phoneNumber.compiledNumberString),
                  build.milestone == .generalRelease,
                  Networking.config.environment == .production else { return }

            var body = "Logged analytics event \"\(event.name)\"."
            if let uiElementName = parameters["ui_element"] {
                body = "Tapped element \"\(uiElementName)\"."
            }

            if let deviceModel = parameters["device_model"],
               let osVersion = parameters["os_version"],
               let exception = await notificationService.notifyOfPrevaricationModeAnalyticsEvent(
                   "ASR [\(deviceModel)/\(osVersion)]",
                   body: body
               ) {
                Logger.log(exception)
            }
        }
    }
}
