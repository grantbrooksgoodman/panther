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

public final class ErrorReportingService: AKReportDelegate {
    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.standardDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.commonServices.metadata) private var metadataService: MetadataService
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var reportedErrorDescriptors = [String]()

    private var reportDelegate: AKReportDelegate?

    // MARK: - Init

    public init() {
        mainQueue.async { self.reportDelegate = ReportDelegate() }
    }

    // MARK: - Computed Properties

    private var commonParams: [String: String] {
        var parameters = ["Language Code": RuntimeStorage.languageCode]

        @Persistent(.currentUserID) var currentUserID: String?
        if let currentUserID {
            parameters["Current User ID"] = currentUserID
        }

        if let presentedViewName = RuntimeStorage.presentedViewName {
            parameters["Presented View Name"] = presentedViewName
        }

        return parameters
    }

    // MARK: - File Report

    public func fileReport(error: AKError) {
        Task { @MainActor in
            var customValues = commonParams
            if let contextCodeComponents = akCore.contextCode(for: .error, metadata: error.metadata)?.components(separatedBy: "."),
               let deviceID = contextCodeComponents.first,
               let operatingSystemID = contextCodeComponents.last {
                customValues["Device Context"] = "\(deviceID) | \(operatingSystemID)"
            }

            let bundleVersionString = "\(build.bundleVersion) (\(build.buildNumber)\(build.stage.shortString))"
            let loggerSessionRecordFilePathString = Logger.sessionRecordFilePath.path()

            var shortDateHash = dateFormatter.string(from: Date()).encodedHash
            shortDateHash = shortDateHash.components[0 ... shortDateHash.components.count / 2].joined()

            guard let errorCode = error.extraParams?["Hashlet"] as? String,
                  let errorDescriptor = error.extraParams?["Descriptor"] as? String,
                  let loggerSessionRecordData = fileManager.contents(atPath: loggerSessionRecordFilePathString),
                  !reportedErrorDescriptors.contains(errorDescriptor) else { return }

            if let exception = await networking.storage.upload(
                loggerSessionRecordData,
                metadata: .init(
                    "reports/\(bundleVersionString)/\(errorCode)/log_\(shortDateHash).txt",
                    contentType: "text/plain",
                    customValues: customValues
                )
            ) {
                Logger.log(exception, with: .toast())
                return
            }

            reportedErrorDescriptors.append(errorDescriptor)
            Observables.rootViewToast.value = .init(
                .capsule(style: .success),
                message: Localized(.errorReportedSuccessfully).wrappedValue,
                perpetuation: build.developerModeEnabled ? .persistent : .ephemeral(.seconds(3))
            )

            guard build.developerModeEnabled else { return }
            Observables.rootViewToastAction.value = {
                guard let urlStringPrefix = self.metadataService.storageReferenceURL?.absoluteString,
                      let encodedBundleVersionString = bundleVersionString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return }
                let urlStringSuffix = "\(self.networking.config.environment.shortString)~2Freports~2F\(encodedBundleVersionString)~2F\(errorCode)"
                guard let url = URL(string: "\(urlStringPrefix)~2F\(urlStringSuffix)") else { return }
                self.uiApplication.open(url)
            }
        }
    }

    public func fileReport(forBug: Bool, body: String, prompt: String, metadata: [Any]) {
        reportDelegate?.fileReport(forBug: forBug, body: body, prompt: prompt, metadata: metadata)
    }
}

private extension String {
    var capitalizingWords: String {
        let components = components(separatedBy: ": ")
        guard components.count > 1 else { return firstUppercase }
        return "\(components[0].firstUppercase): \(components[1].firstUppercase)"
    }
}
