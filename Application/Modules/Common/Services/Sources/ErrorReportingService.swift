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

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class ErrorReportingService: AlertKit.ReportDelegate {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.uiApplication.keyViewController?.frontmostViewController) private var frontmostViewController: UIViewController?
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    private var reportedErrorCodes = [String]()

    // MARK: - Init

    public init() {}

    // MARK: - Computed Properties

    private var commonParams: [String: String] {
        var parameters = [
            "Build SKU": build.buildSKU,
            "Connection Status": build.isOnline ? "online" : "offline",
            "Device Model": "\(SystemInformation.modelName) (\(SystemInformation.modelCode.lowercased()))",
            "Internal Version": "\(build.bundleVersion) (\(build.buildNumber)\(build.stage.shortString))",
            "Language Code": RuntimeStorage.languageCode,
            "OS Version": SystemInformation.osVersion.lowercased(),
            "Project ID": build.projectID,
            "Release Version": "\(build.bundleReleaseVersion) (\(build.releaseBuildNumber)\(build.stage.shortString))",
            "Timestamp": dateFormatter.string(from: .now),
        ]

        @Persistent(.currentUserID) var currentUserID: String?
        if let currentUserID {
            parameters["Current User ID"] = currentUserID
        }

        if let frontmostViewController {
            parameters["View ID"] = String(frontmostViewController)
        }

        return parameters
    }

    // MARK: - AlertKit.ReportDelegate Conformance

    public func fileReport(_ error: any AlertKit.Errorable) {
        Task { @MainActor in
            let buildNumberString = "\(build.buildNumber)\(build.stage.shortString)"
            let bundleVersionString = build.bundleReleaseVersion
            let loggerSessionRecordFilePathString = Logger.sessionRecordFilePath.path()

            var shortDateHash = dateFormatter.string(from: Date()).encodedHash
            shortDateHash = shortDateHash.components[0 ... shortDateHash.components.count / 2].joined()

            guard error.id.count > 3,
                  let loggerSessionRecordData = fileManager.contents(atPath: loggerSessionRecordFilePathString) else { return }

            let errorCode = error.id.components[0 ... 3].joined().uppercased()
            guard !reportedErrorCodes.contains(errorCode) else { return }

            if let exception = await networking.storage.upload(
                loggerSessionRecordData,
                metadata: .init(
                    "reports/\(bundleVersionString)/\(buildNumberString)/\(errorCode)/log_\(shortDateHash).txt",
                    contentType: "text/plain",
                    customValues: commonParams
                )
            ) {
                Logger.log(exception, with: .toast())
                return
            }

            reportedErrorCodes.append(errorCode)
            Observables.rootViewToast.value = .init(
                .capsule(style: .success),
                message: Localized(.errorReportedSuccessfully).wrappedValue,
                perpetuation: build.developerModeEnabled ? .persistent : .ephemeral(.seconds(3))
            )

            guard build.developerModeEnabled else { return }
            Observables.rootViewToastAction.value = {
                guard let urlStringPrefix = self.metadataService.storageReferenceURL?.absoluteString else { return }
                let environmentShortString = self.networking.config.environment.shortString
                let urlStringSuffix = "\(environmentShortString)~2Freports~2F\(bundleVersionString)~2F\(buildNumberString)~2F\(errorCode)"
                guard let url = URL(string: "\(urlStringPrefix)~2F\(urlStringSuffix)") else { return }
                self.uiApplication.open(url)
            }
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
