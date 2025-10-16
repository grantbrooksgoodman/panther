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

@MainActor
public final class BreadcrumbsCaptureService: @preconcurrency AppSubsystem.Delegates.BreadcrumbsCaptureDelegate {
    // MARK: - Types

    public enum CaptureGranularity {
        case broad
        case narrow
    }

    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.breadcrumbsDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public nonisolated static let shared = BreadcrumbsCaptureService()

    public private(set) var captureGranularity: CaptureGranularity = .broad
    public private(set) var savesToPhotos = true

    private var captureTask: Task<Void, Never>?
    private var recordedViewControllers = Set<String>()
    private var recordedViews = Set<String>()

    // MARK: - Computed Properties

    public private(set) var captureFrequency: Duration {
        get { @Persistent(.breadcrumbsCaptureFrequency) var persistedValue: Duration?; return persistedValue ?? .seconds(10) }
        set { @Persistent(.breadcrumbsCaptureFrequency) var persistedValue: Duration?; persistedValue = newValue }
    }

    public var isCapturing: Bool { captureTask != nil }

    private var captureHistory: Set<String> {
        get { @Persistent(.breadcrumbsCaptureHistory) var persistedValue: Set<String>?; return persistedValue ?? .init() }
        set { @Persistent(.breadcrumbsCaptureHistory) var persistedValue: Set<String>?; persistedValue = newValue }
    }

    private var commonParams: [String: String] {
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

    @discardableResult
    public func startCapture() -> Exception? {
        guard !isCapturing else {
            return .init(
                "Breadcrumbs capture is already running.",
                metadata: .init(sender: self)
            )
        }

        captureTask = Task { @MainActor in
            while !Task.isCancelled,
                  isCapturing {
                capture()
                try? await Task.sleep(for: captureFrequency)
            }
        }

        return nil
    }

    @discardableResult
    public func stopCapture() -> Exception? {
        guard isCapturing else {
            return .init(
                "Breadcrumbs capture is not running.",
                metadata: .init(sender: self)
            )
        }

        captureTask?.cancel()
        captureTask = nil
        return nil
    }

    // MARK: - Set Capture Frequency

    public func setCaptureFrequency(_ captureFrequency: Duration) {
        self.captureFrequency = captureFrequency
    }

    // MARK: - Set Capture Granularity

    public func setCaptureGranularity(_ captureGranularity: CaptureGranularity) {
        self.captureGranularity = captureGranularity
    }

    // MARK: - Set Saves to Photos

    public func setSavesToPhotos(_ savesToPhotos: Bool) {
        self.savesToPhotos = savesToPhotos
    }

    // MARK: - Auxiliary

    private func capture() {
        guard Int.random(in: 1 ... 1_000_000) % 3 == 0 else { return }

        var viewHierarchyID: String?
        switch captureGranularity {
        case .broad:
            viewHierarchyID = (uiApplication
                .presentedViews
                .map(\.descriptor) + ["\(build.buildNumber)\(build.milestone.shortString)"])
                .sorted()
                .joined()
                .encodedHash

        case .narrow:
            viewHierarchyID = (uiApplication
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
              let image = uiApplication.snapshot else { return }

        captureHistory.insert(viewHierarchyID)
        self.captureHistory = captureHistory
        Observables.breadcrumbsDidCapture.trigger()

        Task.detached(priority: .background) {
            guard let imageData = image.dataCompressed(toKB: 100) ?? image.jpegData(compressionQuality: 0.5) else { return }

            await self.uploadBreadcrumb(
                imageData: imageData,
                viewHierarchyID: viewHierarchyID
            )

            let filePath = await self.filePath; try? imageData.write(to: filePath)

            guard await self.savesToPhotos else { return }
            await MainActor.run { UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil) }
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
        let viewDescriptors = Set(presentedViewControllers.compactMap(\.view?.traversedSubviews).reduce([], +).map(\.descriptor))

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

        additionalMetadata = additionalMetadata.merging(commonParams) { _, new in new }

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
            build.bundleRevision,
            "\(build.buildNumber)\(build.milestone.shortString)",
            "\(keyDescriptor)\(keyDescriptor == leafDescriptor ? "" : " & \(leafDescriptor)")",
        ].joined(separator: "/") + "/\(fileName).\(ImageFileExtension.jpeg.rawValue)"

        Task.detached(priority: .background) {
            // NIT: Using local dependency because I *think* a class-scoped property would be on the main actor.
            @Dependency(\.networking.storage) var storage: StorageDelegate

            if let exception = await storage.upload(
                imageData,
                metadata: .init(
                    filePath,
                    contentType: ImageFileExtension.jpeg.contentTypeString,
                    customValues: additionalMetadata.isEmpty ? nil : additionalMetadata
                )
            ) {
                Logger.log(
                    exception,
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
        return formatter
    }
}

private extension DependencyValues {
    var breadcrumbsDateFormatter: DateFormatter {
        get { self[BreadcrumbsDateFormatterDependency.self] }
        set { self[BreadcrumbsDateFormatterDependency.self] = newValue }
    }
}
