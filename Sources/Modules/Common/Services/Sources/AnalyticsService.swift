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
    @Dependency(\.uiApplication.keyViewController?.frontmostViewController) private var frontmostViewController: UIViewController?
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

        @Persistent(.currentUserID) var currentUserID: String?
        if let currentUserID {
            parameters["current_user_id"] = currentUserID
        }

        if let frontmostViewController {
            parameters["view_id"] = String(type(of: frontmostViewController))
        }

        return parameters
    }

    // MARK: - Log Event

    public func logEvent(_ event: AnalyticsEvent, extraParams: [String: String]? = nil) {
        Task { @MainActor in
            if !CommandLine.arguments.containsAllStrings(in: ["-FIRAnalyticsDebugEnabled", "-FIRDebugEnabled"]) {
                guard Networking.config.environment == .production,
                      build.milestone == .generalRelease else { return }
            }

            var parameters = commonParams
            if let extraParams {
                extraParams.forEach { parameters[$0] = $1 }
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
                    extraParams: parameters,
                    metadata: [self, #file, #function, #line]
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
