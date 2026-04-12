//
//  ErrorReportingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

final class ErrorReportingService: AlertKit.ReportDelegate, @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.errorReportingDateFormatter) private var serviceDateFormatter: DateFormatter
    @Dependency(\.timestampDateFormatter) private var timestampDateFormatter: DateFormatter
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    private(set) var reportedErrorCodes = [String]()

    // MARK: - Computed Properties

    private var userInfo: [String: String] {
        var parameters = [
            "Build SKU": build.buildSKU,
            "Bundle Revision": "\(build.bundleRevision) (\(build.revisionBuildNumber))",
            "Bundle Version": "\(build.bundleVersion) (\(build.buildNumber)\(build.milestone.shortString))",
            "Connection Status": build.isOnline ? "online" : "offline",
            "Device Model": "\(SystemInformation.modelName) (\(SystemInformation.modelCode.lowercased()))",
            "Language Code": RuntimeStorage.languageCode,
            "OS Version": SystemInformation.osVersion.lowercased(),
            "Project ID": build.projectID,
            "Timestamp": timestampDateFormatter.string(from: .now),
        ]

        if let currentUserID = User.currentUserID {
            parameters["Current User ID"] = currentUserID
        }

        if let leafViewController = uiApplication.keyViewController?.leafViewController {
            parameters["View ID"] = leafViewController.descriptor
        }

        return parameters
    }

    // MARK: - File Report

    func fileReport(_ error: any AlertKit.Errorable) {
        _fileReport(error)
    }

    func fileReport(
        _ error: any AlertKit.Errorable,
        showsToastOnSuccess: Bool
    ) {
        _fileReport(error, showsToastOnSuccess: showsToastOnSuccess)
    }

    private func _fileReport(
        _ error: any AlertKit.Errorable,
        showsToastOnSuccess: Bool = true
    ) {
        Task { @MainActor in
            guard let loggerSessionRecordData = fileManager.contents(
                atPath: Logger.sessionRecordFilePath.path()
            ) else { return }

            let errorCode = error.id.components.prefix(4).joined().uppercased()
            guard !reportedErrorCodes.contains(errorCode) else { return }

            let exceptionDescriptor = error.userInfo?["Descriptor"] as? String
            var parentDirectoryName = (error.userInfo?["HostedOverrideErrorCode"] as? String) ?? errorCode
            if let exceptionDescriptor,
               error.userInfo?["StaticErrorCode"] == nil {
                parentDirectoryName = "\(parentDirectoryName)_\(exceptionDescriptor.shorthandErrorDescriptor)"
            }

            let shortDateHash = timestampDateFormatter
                .string(from: .now)
                .encodedHash
                .components
                .prefix(5)
                .joined()

            let fileNameSuffix = [
                build.milestone.shortString,
                String(build.buildNumber),
                build.bundleRevision,
                "_\(shortDateHash)",
            ].joined()

            let filePath = [
                "reports",
                build.bundleVersion,
                parentDirectoryName,
                "\(serviceDateFormatter.string(from: .now))_\(fileNameSuffix).txt",
            ].joined(separator: "/")

            let userInfo = (error.userInfo?.compactMapValues { $0 as? String } ?? [:])
                .filter {
                    $0.key != "Descriptor" &&
                        $0.key != "ErrorCode" &&
                        $0.key != "HostedOverrideErrorCode" &&
                        $0.key != "StaticErrorCode"
                }

            @Dependency(\.networking.storage) var storage: StorageDelegate
            if let exception = await storage.upload(
                loggerSessionRecordData,
                metadata: .init(
                    filePath,
                    contentType: "text/plain",
                    customValues: userInfo.plus(keys: [
                        "Error Description": exceptionDescriptor ?? error.description,
                    ]).plus(keys: self.userInfo)
                )
            ) {
                guard Logger.reportsErrorsAutomatically else {
                    return Logger.log(exception, with: .toast)
                }

                Logger.setReportsErrorsAutomatically(false)
                Logger.log(exception, with: .toast)
                Logger.setReportsErrorsAutomatically(true)

                return
            }

            reportedErrorCodes.append(errorCode)
            guard showsToastOnSuccess,
                  !Logger.reportsErrorsAutomatically else { return }

            var toastAction: (@Sendable () -> Void)? {
                guard self.build.isDeveloperModeEnabled,
                      let urlStringPrefix = self.metadataService.storageReferenceURL?.absoluteString else { return nil }

                let urlString = urlStringPrefix + [
                    Networking.config.environment.shortString,
                    "reports",
                    build.bundleVersion,
                    parentDirectoryName,
                ].map {
                    $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0
                }.joined(separator: "~2F")

                guard let url = URL(string: urlString) else { return nil }
                return { @Sendable in
                    self.uiApplication.open(url)
                    self.uiPasteboard.string = url.absoluteString
                }
            }

            Toast.show(
                .init(
                    .capsule(style: .success),
                    message: Localized(.errorReportedSuccessfully).wrappedValue,
                    perpetuation: build.isDeveloperModeEnabled ? .persistent : .ephemeral(.seconds(3))
                ),
                onTap: toastAction
            )
        }
    }
}

private enum ErrorReportingDateFormatterDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        formatter.locale = .init(identifier: "en_US_POSIX")
        return formatter
    }
}

private extension DependencyValues {
    var errorReportingDateFormatter: DateFormatter {
        get { self[ErrorReportingDateFormatterDependency.self] }
        set { self[ErrorReportingDateFormatterDependency.self] = newValue }
    }
}

private extension Dictionary {
    func plus(keys other: [Key: Value]) -> Dictionary {
        merging(other) { _, new in new }
    }
}

private extension String {
    var shorthandErrorDescriptor: String {
        let excludedWords: Set<String> = [
            "A",
            "AN",
            "BEEN",
            "HAS",
            "IS",
            "THE",
            "WAS",
        ]

        return trimmingCharacters(in: .punctuationCharacters)
            .uppercased()
            .components(separatedBy: .whitespaces)
            .map(\.trimmingWhitespace)
            .filter { !excludedWords.contains($0) }
            .prefix(3)
            .joined(separator: "_")
    }
}
