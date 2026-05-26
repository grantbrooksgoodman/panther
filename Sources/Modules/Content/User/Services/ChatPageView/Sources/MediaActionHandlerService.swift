//
//  MediaActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import AVFoundation
import Foundation
import QuickLook
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

@MainActor
final class MediaActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.MediaActionHandler
    private typealias Strings = AppConstants.Strings.ChatPageViewService.MediaActionHandler

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.qlThumbnailGenerator) private var qlThumbnailGenerator: QLThumbnailGenerator
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private(set) var isPresentingPickerController = false

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Attach Media Button Tapped

    func attachMediaButtonTapped() {
        services.haptics.generateFeedback(.medium)

        let takePhotoAction: AKAction = .init("Take photo") {
            Task { @MainActor in
                self.presentCameraPicker()
            }
        }

        let selectDocumentAction: AKAction = .init("Select document") {
            Task { @MainActor in
                self.presentDocumentPicker()
            }
        }

        let selectPhotoOrVideoAction: AKAction = .init("Select photo or video") {
            Task { @MainActor in
                self.presentMediaPicker()
            }
        }

        Task {
            await AKActionSheet(
                title: "Attach media",
                actions: [
                    takePhotoAction,
                    selectDocumentAction,
                    selectPhotoOrVideoAction,
                ],
                cancelButtonTitle: Localized(.cancel).wrappedValue,
                sourceItem: .custom(.view(
                    viewController.messageInputBar.leftStackView.attachMediaButton
                ))
            ).present(translating: [
                .title,
                .actions(),
            ])
        }
    }

    // MARK: - Process & Send Document

    private func processAndSendDocument(_ url: URL) async throws(Exception) {
        guard let fileExtension = url
            .path()
            .components(separatedBy: "/")
            .last?
            .components(separatedBy: ".")
            .last,
            let mediaFileExtension = MediaFileExtension(fileExtension) else {
            throw Exception(
                "Failed to determine file type.",
                metadata: .init(sender: self)
            )
        }

        let relativePath = [
            NetworkPath.media.rawValue,
            "\(Strings.defaultDocumentName).\(mediaFileExtension.rawValue)",
        ].joined(separator: "/")

        let localPathURL = fileManager
            .documentsDirectoryURL
            .appending(path: relativePath)

        do {
            let data = try Data.fromURL(url)
            guard !mediaFileExtension.isImage else {
                if let image = UIImage(data: data) {
                    return try await processAndSendImage(
                        image
                    )
                }

                throw Exception(
                    "Failed to process image data.",
                    metadata: .init(sender: self)
                )
            }

            try fileManager.createFile(
                atPath: localPathURL,
                data: data
            )

            let image = try await getThumbnailImage(
                url,
                contentType: mediaFileExtension
            )

            guard let imageData = image.dataCompressed(toKB: Int(Floats.imageCompressionSizeKB)),
                  let thumbnailPath = localPathURL.thumbnailPath else {
                throw Exception(
                    "Failed to process thumbnail data.",
                    metadata: .init(sender: self)
                )
            }

            try fileManager.createFile(
                atPath: thumbnailPath,
                data: imageData
            )

            try await messageDeliveryService.sendMediaMessage(.init(
                relativePath,
                name: Strings.defaultDocumentName,
                fileExtension: mediaFileExtension
            ))
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Process & Send Image

    private func processAndSendImage(
        _ image: UIImage
    ) async throws(Exception) {
        guard let data = image.dataCompressed(
            toKB: Int(Floats.imageCompressionSizeKB)
        ) else {
            throw Exception(
                "Failed to compress image.",
                metadata: .init(sender: self)
            )
        }

        let relativePath = [
            NetworkPath.media.rawValue,
            "\(Strings.defaultImageName).\(MediaFileExtension.image(.jpeg).rawValue)",
        ].joined(separator: "/")

        let localPathURL = fileManager
            .documentsDirectoryURL
            .appending(path: relativePath)

        try fileManager.createFile(
            atPath: localPathURL,
            data: data
        )

        try await messageDeliveryService.sendMediaMessage(.init(
            relativePath,
            name: Strings.defaultImageName,
            fileExtension: .image(.jpeg)
        ))
    }

    // MARK: - Process & Send Video

    private func processAndSendVideo(
        _ url: URL
    ) async throws(Exception) {
        let relativePath = [
            NetworkPath.media.rawValue,
            "\(Strings.defaultVideoName).\(MediaFileExtension.video(.mp4).rawValue)",
        ].joined(separator: "/")

        let localPathURL = fileManager
            .documentsDirectoryURL
            .appending(path: relativePath)

        try await compressVideo(
            at: url,
            outputURL: localPathURL
        )

        let image = try await getThumbnailImage(
            localPathURL,
            contentType: .video(.mp4)
        )

        guard let imageData = image.dataCompressed(toKB: Int(Floats.imageCompressionSizeKB)),
              let thumbnailPath = localPathURL.thumbnailPath else {
            throw Exception(
                "Failed to process thumbnail data.",
                metadata: .init(sender: self)
            )
        }

        try fileManager.createFile(
            atPath: thumbnailPath,
            data: imageData
        )

        try await messageDeliveryService.sendMediaMessage(.init(
            relativePath,
            name: Strings.defaultVideoName,
            fileExtension: .video(.mp4)
        ))
    }

    // MARK: - Auxiliary

    private func compressVideo(
        at urlPath: URL,
        outputURL: URL
    ) async throws(Exception) {
        let urlAsset = AVURLAsset(url: urlPath, options: nil)

        guard let exportSession = AVAssetExportSession(
            asset: urlAsset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw Exception(
                "Failed to create export session.",
                metadata: .init(sender: self)
            )
        }

        if fileManager.fileExists(atPath: outputURL.path()) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }
        }

        exportSession.outputFileType = .mp4
        exportSession.outputURL = outputURL

        let error: Error? = await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume(returning: exportSession.error)
            }
        }

        if let error {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func getThumbnailImage(
        _ url: URL,
        contentType: MediaFileExtension
    ) async throws(Exception) -> UIImage {
        switch contentType {
        case .document:
            let request: QLThumbnailGenerator.Request = .init(
                fileAt: url,
                size: .init(
                    width: Floats.thumbnailImageSizeWidth,
                    height: Floats.thumbnailImageSizeHeight
                ),
                scale: Floats.thumbnailImageScale,
                representationTypes: .thumbnail
            )

            do {
                return try await qlThumbnailGenerator.generateBestRepresentation(
                    for: request
                ).uiImage
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }

        case .video:
            let assetImageGenerator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            assetImageGenerator.appliesPreferredTrackTransform = true

            do {
                let cgImage = try assetImageGenerator.copyCGImage(
                    at: .init(
                        seconds: 1,
                        preferredTimescale: .init(
                            Floats.avAssetImageGeneratorPreferredTimescale
                        )
                    ),
                    actualTime: nil
                )
                return .init(cgImage: cgImage)
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }

        default:
            throw Exception(
                "Cannot generate thumbnail for specified media file extension.",
                userInfo: ["MediaFileExtensionRawValue": contentType.rawValue],
                metadata: .init(sender: self)
            )
        }
    }

    @MainActor
    private func onContentPickerDismissed(
        _ callback: Callback<ContentPickerResult, Exception>?
    ) async throws(Exception) {
        StatusBar.overrideStyle(.appAware)
        Task.delayed(by: .seconds(1)) { @MainActor in
            StatusBar.overrideStyle(.appAware)
        }

        guard let callback else { return }

        switch callback {
        case let .success(result):
            switch result {
            case let .document(url):
                try await processAndSendDocument(url)

            case let .image(image):
                try await processAndSendImage(image)

            case let .video(url):
                try await processAndSendVideo(url)
            }

        case let .failure(exception):
            throw exception
        }
    }

    private func presentCameraPicker() {
        StatusBar.overrideStyle(.conditionalLightContent)
        services.contentPicker.camera.present()
        isPresentingPickerController = true

        services.contentPicker.camera.onDismiss { result in
            Task {
                // FIXME: Should delay this to allow ChatPageViewController.viewWillAppear(_:) to fire.
                self.isPresentingPickerController = false
                do throws(Exception) {
                    try await self.onContentPickerDismissed(result)
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }
    }

    private func presentDocumentPicker() {
        StatusBar.overrideStyle(.conditionalLightContent)
        services.contentPicker.document.present()
        isPresentingPickerController = true

        services.contentPicker.document.onDismiss { result in
            Task {
                self.isPresentingPickerController = false
                do throws(Exception) {
                    try await self.onContentPickerDismissed(result)
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }
    }

    private func presentMediaPicker() {
        StatusBar.overrideStyle(.conditionalLightContent)
        services.contentPicker.media.present()
        isPresentingPickerController = true

        services.contentPicker.media.onDismiss { result in
            Task {
                self.isPresentingPickerController = false
                do throws(Exception) {
                    try await self.onContentPickerDismissed(result)
                } catch {
                    Logger.log(
                        error,
                        with: .toast
                    )
                }
            }
        }
    }
}

// swiftlint:enable file_length type_body_length
