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

/// Use ``AnalyticsService`` to report usage events to the analytics backend.
///
/// Events are reported with a standard set of metadata describing the build, device, language,
/// current user, and visible view.
struct AnalyticsService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.entity.user.currentUser) private var currentUser: User?
    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Types

    /// A usage event that can be reported to the analytics backend.
    enum AnalyticsEvent: String {
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

        /// The event name in snake case, as reported to the analytics backend.
        var name: String {
            rawValue.snakeCased
        }
    }

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether analytics data collection is enabled.
    ///
    /// Data collection is enabled on general-release builds in the production environment, or
    /// when the app is launched with the Firebase Analytics debugging arguments.
    static let shouldEnableDataCollection: Bool = {
        @Dependency(\.build) var build: Build

        if !CommandLine.arguments.containsAllStrings(
            in: [
                "-FIRAnalyticsDebugEnabled",
                "-FIRDebugEnabled",
            ]
        ) {
            guard Networking.config.environment == .production,
                  build.milestone == .generalRelease else { return false }
            return true
        }

        return true
    }()

    // MARK: - Properties

    @MainActor
    private var userInfo: [String: String] {
        @Dependency(\.uiApplication.keyViewController?.leafViewController) var leafViewController: UIViewController?
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

    /// Reports the given event to the analytics backend.
    ///
    /// The event is reported asynchronously with the standard metadata set; this method returns
    /// immediately. Parameter values longer than 40 characters are truncated. If
    /// ``shouldEnableDataCollection`` is `false`, the event is discarded.
    ///
    /// When the current user is signed in with a designated test account on a general-release
    /// build in the production environment, the event is additionally forwarded to the
    /// notification service.
    ///
    /// - Parameters:
    ///   - event: The event to report.
    ///   - additionalUserInfo: Additional parameters to attach to the event, overriding
    ///     standard metadata values with matching keys. The default is `nil`.
    func logEvent(
        _ event: AnalyticsEvent,
        additionalUserInfo: [String: String]? = nil
    ) {
        Task { @MainActor in
            guard AnalyticsService.shouldEnableDataCollection else { return }

            var parameters = userInfo
            if let additionalUserInfo {
                additionalUserInfo.forEach { parameters[$0] = $1 }
            }

            for (key, value) in parameters {
                guard value.count > 40 else { continue }
                var clippedValue = value
                while clippedValue.count > 40 {
                    clippedValue = clippedValue.dropSuffix()
                }
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
               let osVersion = parameters["os_version"] {
                do throws(Exception) {
                    try await notificationService.notifyOfPrevaricationModeAnalyticsEvent(
                        "ASR [\(deviceModel)/\(osVersion)]",
                        body: body
                    )
                } catch {
                    Logger.log(error)
                }
            }
        }
    }
}
