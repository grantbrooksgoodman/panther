//
//  AnalyticsService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import FirebaseAnalytics

public struct AnalyticsService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.uiApplication.keyViewController?.frontmostViewController) private var frontmostViewController: UIViewController?
    @Dependency(\.networking.config) private var networkConfig: NetworkConfig

    // MARK: - Types

    public enum AnalyticsEvent: String {
        /* MARK: Cases */

        case accessChat
        case accessNewChatPage

        case clearCaches
        case closeApp
        case createNewConversation

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
            "bundle_version": "\(build.bundleVersion) (\(build.buildNumber)\(build.stage.shortString))",
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
                guard networkConfig.environment == .production,
                      build.stage == .generalRelease else { return }
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
                    extraParams: parameters,
                    metadata: [self, #file, #function, #line]
                ),
                domain: .analytics
            )

            Analytics.logEvent(event.name, parameters: parameters)
        }
    }
}
