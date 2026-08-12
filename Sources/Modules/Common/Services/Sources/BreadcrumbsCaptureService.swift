//
//  BreadcrumbsCaptureService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

/// Use ``BreadcrumbsCaptureService`` to periodically capture screenshots of novel view
/// hierarchies for diagnostic purposes.
///
/// While capture is running, the service periodically snapshots the screen when it detects a
/// view hierarchy it has not yet recorded, uploads the image to remote storage with metadata
/// describing the build, device, and visible views, and writes a copy to the app's Documents
/// directory – optionally also saving it to the user's photo library. Recorded view
/// hierarchies persist across launches; each capture cycle proceeds with approximately
/// one-in-three probability.
@MainActor
final class BreadcrumbsCaptureService: AppSubsystem.Delegates.BreadcrumbsCaptureDelegate {
    // MARK: - Types

    /// The strategy for identifying view hierarchies during capture.
    enum CaptureGranularity {
        /// Identifies view hierarchies by every presented view.
        case broad

        /// Identifies view hierarchies by only visible, interactive views not previously
        /// recorded.
        case narrow
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.breadcrumbsDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    /// The shared breadcrumbs capture service instance.
    nonisolated static let shared = BreadcrumbsCaptureService()

    /// The granularity with which view hierarchies are identified. The default is
    /// ``CaptureGranularity/broad``.
    private(set) var captureGranularity: CaptureGranularity = .broad

    /// A Boolean value that indicates whether captured screenshots are also saved to the
    /// user's photo library. The default is `true`.
    private(set) var savesToPhotos = true

    @SharedEvent(\.breadcrumbsDidCapture) private var breadcrumbsDidCapture
    private var captureTask: Task<Void, Never>?
    private var recordedViewControllers = Set<String>()
    private var recordedViews = Set<String>()

    // MARK: - Computed Properties

    /// The interval between capture cycles. The default is 10 seconds.
    ///
    /// This value persists across launches.
    private(set) var captureFrequency: Duration {
        get { @Persistent(.breadcrumbsCaptureFrequency) var persistedValue: Duration?; return persistedValue ?? .seconds(10) }
        set { @Persistent(.breadcrumbsCaptureFrequency) var persistedValue: Duration?; persistedValue = newValue }
    }

    /// A Boolean value that indicates whether capture is running.
    var isCapturing: Bool {
        captureTask != nil
    }

    private var captureHistory: Set<String> {
        get { @Persistent(.breadcrumbsCaptureHistory) var persistedValue: Set<String>?; return persistedValue ?? .init() }
        set { @Persistent(.breadcrumbsCaptureHistory) var persistedValue: Set<String>?; persistedValue = newValue }
    }

    private var userInfo: [String: String] {
        [
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
    }

    private var filePath: URL {
        let documents = fileManager.documentsDirectoryURL
        let timeString = dateFormatter.string(from: .now)

        var fileName: String!
        if let leafViewController = uiApplication.keyViewController?.leafViewController {
            fileName = "\(build.codeName)_\(leafViewController.descriptor) @ \(timeString).png"
        } else {
            let fileNamePrefix = "\(build.codeName)_\(String(build.buildNumber))"
            let fileNameSuffix = "\(build.milestone.shortString) | \(build.bundleRevision) @ \(timeString).png"
            fileName = fileNamePrefix + fileNameSuffix
        }

        return documents.appending(path: fileName)
    }

    // MARK: - Object Lifecycle

    private nonisolated init() {}

    deinit {
        captureTask?.cancel()
        captureTask = nil
    }

    // MARK: - Capture

    /// Starts the periodic capture loop.
    ///
    /// Capture cycles repeat at the interval given by ``captureFrequency`` until
    /// ``stopCapture()`` is called.
    ///
    /// - Throws: An `Exception` if capture is already running.
    func startCapture() throws(Exception) {
        guard !isCapturing else {
            throw Exception(
                "Breadcrumbs capture is already running.",
                metadata: .init(sender: self)
            )
        }

        captureTask = Task { @MainActor in
            while !Task.isCancelled,
                  isCapturing {
                await capture()
                try? await Task.sleep(for: captureFrequency)
            }
        }
    }

    /// Stops the periodic capture loop.
    ///
    /// - Throws: An `Exception` if capture is not running.
    func stopCapture() throws(Exception) {
        guard isCapturing else {
            throw Exception(
                "Breadcrumbs capture is not running.",
                metadata: .init(sender: self)
            )
        }

        captureTask?.cancel()
        captureTask = nil
    }

    // MARK: - Set Capture Frequency

    /// Sets the interval between capture cycles.
    ///
    /// - Parameter captureFrequency: The interval to set.
    func setCaptureFrequency(_ captureFrequency: Duration) {
        self.captureFrequency = captureFrequency
    }

    // MARK: - Set Capture Granularity

    /// Sets the granularity with which view hierarchies are identified.
    ///
    /// - Parameter captureGranularity: The granularity to set.
    func setCaptureGranularity(_ captureGranularity: CaptureGranularity) {
        self.captureGranularity = captureGranularity
    }

    // MARK: - Set Saves to Photos

    /// Sets whether captured screenshots are also saved to the user's photo library.
    ///
    /// - Parameter savesToPhotos: A Boolean value that indicates whether to save captured
    ///   screenshots to the photo library.
    func setSavesToPhotos(_ savesToPhotos: Bool) {
        self.savesToPhotos = savesToPhotos
    }

    // MARK: - Auxiliary

    private func capture() async {
        guard Int.random(in: 1 ... 1_000_000) % 3 == 0 else { return }

        let viewHierarchyID: String? = switch captureGranularity {
        case .broad:
            (
                uiApplication
                    .presentedViews
                    .map(\.descriptor) + ["\(build.buildNumber)\(build.milestone.shortString)"]
            )
            .sorted()
            .joined()
            .encodedHash

        case .narrow:
            (
                uiApplication
                    .presentedViews
                    .unique
                    .filter {
                        $0.alpha > 0 &&
                            $0.frame != .zero &&
                            !$0.isHidden &&
                            $0.isUserInteractionEnabled
                    }
                    .map(\.descriptor)
                    .filter { !recordedViews.contains($0) } + ["\(build.buildNumber)\(build.milestone.shortString)"]
            )
            .sorted()
            .joined()
            .encodedHash
        }

        var captureHistory = captureHistory
        guard let viewHierarchyID,
              !captureHistory.contains(viewHierarchyID),
              let image = await uiApplication.snapshot else { return }

        captureHistory.insert(viewHierarchyID)
        self.captureHistory = captureHistory
        breadcrumbsDidCapture.send()

        Task.detached(priority: .background) {
            guard let imageData = image.dataCompressed(toKB: 100) ?? image.jpegData(compressionQuality: 0.5) else { return }

            await self.uploadBreadcrumb(
                imageData: imageData,
                viewHierarchyID: viewHierarchyID
            )

            let filePath = await self.filePath
            try? imageData.write(to: filePath)

            guard await self.savesToPhotos else { return }
            await MainActor.run {
                UIImageWriteToSavedPhotosAlbum(
                    image,
                    nil,
                    nil,
                    nil
                )
            }
        }
    }

    private func uploadBreadcrumb(
        imageData: Data,
        viewHierarchyID: String
    ) async {
        guard let keyViewController = uiApplication.keyViewController else {
            return Logger.log(.init(
                "Failed to resolve key view controller.",
                metadata: .init(sender: self)
            ))
        }

        let keyViewDescriptor = uiApplication.firstResponder?.descriptor ?? keyViewController
            .leafViewController
            .view
            .traversedSubviews
            .unique
            .filter {
                $0.alpha > .zero &&
                    $0.frame != .zero &&
                    !$0.isHidden &&
                    $0.isUserInteractionEnabled
            }
            .first?
            .descriptor

        let presentedViewControllers = uiApplication.presentedViewControllers

        let viewControllerDescriptors = Set(presentedViewControllers.map(\.descriptor))
        let viewDescriptors = Set(
            presentedViewControllers
                .flatMap { $0.view?.traversedSubviews ?? [] }
                .map(\.descriptor)
        )

        let novelViewControllers = viewControllerDescriptors.subtracting(recordedViewControllers)
        let novelViews = viewDescriptors.subtracting(recordedViews)

        viewDescriptors.forEach { recordedViews.insert($0) }
        viewControllerDescriptors.forEach { recordedViewControllers.insert($0) }

        var additionalMetadata = [
            "KeyViewController": keyViewController.descriptor,
            "LeafViewController": keyViewController.leafViewController.descriptor,
        ]

        if let firstResponderDescriptor = uiApplication.mainWindow?.traversedSubviews.first(where: \.isFirstResponder)?.descriptor {
            additionalMetadata["FirstResponder"] = firstResponderDescriptor
        }

        if !recordedViewControllers.isEmpty,
           !novelViewControllers.isEmpty {
            additionalMetadata["NovelViewControllers"] = novelViewControllers.joined(separator: ", ")
        }

        if !recordedViews.isEmpty,
           !novelViews.isEmpty {
            additionalMetadata["NovelViews"] = novelViews.joined(separator: ", ")
        }

        additionalMetadata = additionalMetadata.merging(userInfo) { _, new in new }

        // swiftlint:disable line_length
        let keyDescriptor = keyViewController.descriptor.components(separatedBy: "<").first ?? keyViewController.descriptor
        let leafDescriptor = keyViewController.leafViewController.descriptor.components(separatedBy: "<").first ?? keyViewController.leafViewController.descriptor
        // swiftlint:enable line_length

        var fileName = viewHierarchyID.prefix(8)
        if let keyViewDescriptor {
            fileName = "\(keyViewDescriptor) (\(fileName))"
        }

        let filePath = [
            NetworkPath.breadcrumbs.rawValue,
            build.bundleVersion,
            "\(keyDescriptor)\(keyDescriptor == leafDescriptor ? "" : " & \(leafDescriptor)")",
            "\(fileName).\(ImageFileExtension.jpeg.rawValue)",
        ].joined(separator: "/")

        Task.detached(priority: .background) {
            // NIT: Using local dependency because I *think* a class-scoped property would be on the main actor.
            @Dependency(\.networking.storage) var storage: StorageDelegate
            do throws(Exception) {
                try await storage.upload(
                    imageData,
                    metadata: .init(
                        filePath,
                        contentType: ImageFileExtension.jpeg.contentTypeString,
                        customValues: additionalMetadata.isEmpty ? nil : additionalMetadata
                    )
                )
            } catch {
                Logger.log(
                    error,
                    with: .toastInPrerelease
                )
            }
        }
    }
}

private enum BreadcrumbsDateFormatterDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        formatter.locale = .init(identifier: "en_US_POSIX")
        return formatter
    }
}

private extension DependencyValues {
    var breadcrumbsDateFormatter: DateFormatter {
        get { self[BreadcrumbsDateFormatterDependency.self] }
        set { self[BreadcrumbsDateFormatterDependency.self] = newValue }
    }
}
