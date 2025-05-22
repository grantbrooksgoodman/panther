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

public final class ErrorReportingService: AlertKit.ReportDelegate {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.uiApplication.keyViewController?.frontmostViewController) private var frontmostViewController: UIViewController?
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.uiPasteboard) private var uiPasteboard: UIPasteboard

    // MARK: - Properties

    public private(set) var reportedErrorCodes = [String]()

    // MARK: - Init

    public init() {}

    // MARK: - Computed Properties

    private var commonParams: [String: String] {
        var parameters = [
            "Build SKU": build.buildSKU,
            "Bundle Revision": "\(build.bundleRevision) (\(build.revisionBuildNumber))",
            "Bundle Version": "\(build.bundleVersion) (\(build.buildNumber)\(build.milestone.shortString))",
            "Connection Status": build.isOnline ? "online" : "offline",
            "Device Model": "\(SystemInformation.modelName) (\(SystemInformation.modelCode.lowercased()))",
            "Language Code": RuntimeStorage.languageCode,
            "OS Version": SystemInformation.osVersion.lowercased(),
            "Project ID": build.projectID,
            "Timestamp": dateFormatter.string(from: .now),
        ]

        @Persistent(.currentUserID) var currentUserID: String?
        if let currentUserID {
            parameters["Current User ID"] = currentUserID
        }

        if let frontmostViewController {
            parameters["View ID"] = String(type(of: frontmostViewController))
        }

        return parameters
    }

    // MARK: - File Report

    public func fileReport(_ error: any AlertKit.Errorable) {
        _fileReport(error)
    }

    public func fileReport(
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
            let buildNumberString = "\(build.buildNumber)\(build.milestone.shortString)"
            let bundleVersionString = build.bundleVersion
            let loggerSessionRecordFilePathString = Logger.sessionRecordFilePath.path()

            var shortDateHash = dateFormatter.string(from: Date.now).encodedHash
            shortDateHash = shortDateHash.components[0 ... shortDateHash.components.count / 2].joined()

            guard error.id.count > 3,
                  let loggerSessionRecordData = fileManager.contents(atPath: loggerSessionRecordFilePathString) else { return }

            let errorCode = error.id.components[0 ... 3].joined().uppercased()
            guard !reportedErrorCodes.contains(errorCode) else { return }

            if let exception = await networking.storage.upload(
                loggerSessionRecordData,
                metadata: .init(
                    "reports/\(bundleVersionString)/\(errorCode)/\(build.bundleRevision) | \(buildNumberString)/log_\(shortDateHash).txt",
                    contentType: "text/plain",
                    customValues: commonParams
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

            var toastAction: (() -> Void)? {
                guard self.build.isDeveloperModeEnabled,
                      let urlStringPrefix = self.metadataService.storageReferenceURL?.absoluteString, // swiftlint:disable:next line_length
                      let encodedRevisionString = "\(build.bundleRevision) | \(buildNumberString)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
                let environmentShortString = Networking.config.environment.shortString
                let urlStringSuffix = "\(environmentShortString)~2Freports~2F\(bundleVersionString)~2F\(errorCode)~2F\(encodedRevisionString)"
                guard let url = URL(string: "\(urlStringPrefix)~2F\(urlStringSuffix)") else { return nil }
                return {
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

private extension String {
    var capitalizingWords: String {
        let components = components(separatedBy: ": ")
        guard components.count > 1 else { return firstUppercase }
        return "\(components[0].firstUppercase): \(components[1].firstUppercase)"
    }
}
