//
//  MediaActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable type_body_length

/* Native */
import AVFoundation
import Foundation
import QuickLook
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public final class MediaActionHandlerService {
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

    public private(set) var isPresentingPickerController = false

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Attach Media Button Tapped

    public func attachMediaButtonTapped() {
        services.haptics.generateFeedback(.medium)

        let takePhotoAction: AKAction = .init("Take photo") { self.presentCameraPicker() }
        let selectDocumentAction: AKAction = .init("Select document") { self.presentDocumentPicker() }
        let selectPhotoOrVideoAction: AKAction = .init("Select photo or video") { self.presentMediaPicker() }

        Task {
            await AKActionSheet(
                title: "Attach media",
                actions: [
                    takePhotoAction,
                    selectDocumentAction,
                    selectPhotoOrVideoAction,
                ],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions()])
        }
    }

    // MARK: - Process & Send Document

    private func processAndSendDocument(_ url: URL) async -> Exception? {
        guard let fileExtension = url
            .path()
            .components(separatedBy: "/")
            .last?
            .components(separatedBy: ".")
            .last,
            let mediaFileExtension = MediaFileExtension(fileExtension) else {
            return .init(
                "Failed to determine file type.",
                metadata: [self, #file, #function, #line]
            )
        }

        let networkPath = "\(NetworkPath.media.rawValue)/\(Strings.defaultDocumentName).\(mediaFileExtension.rawValue)"
        let localPath = fileManager.documentsDirectoryURL.appending(path: networkPath)

        let dataFromURLResult = Data.fromURL(url)

        switch dataFromURLResult {
        case let .success(data):
            if let exception = fileManager.createFile(
                atPath: localPath,
                data: data
            ) {
                return exception
            }

            let getThumbnailImageResult = await getThumbnailImage(
                url,
                contentType: mediaFileExtension
            )

            switch getThumbnailImageResult {
            case let .success(image):
                guard let imageData = image.dataCompressed(toKB: Int(Floats.imageCompressionSizeKB)),
                      let thumbnailPath = localPath.thumbnailPath else {
                    return .init("Failed to process thumbnail data.", metadata: [self, #file, #function, #line])
                }

                if let exception = fileManager.createFile(
                    atPath: thumbnailPath,
                    data: imageData
                ) {
                    return exception
                }

                if let exception = await messageDeliveryService.sendMediaMessage(.init(
                    localPath,
                    name: Strings.defaultDocumentName,
                    fileExtension: mediaFileExtension
                )) {
                    return exception
                }

            case let .failure(exception):
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Process & Send Image

    private func processAndSendImage(_ image: UIImage) async -> Exception? {
        guard let data = image.dataCompressed(toKB: Int(Floats.imageCompressionSizeKB)) else {
            return .init("Failed to compress image.", metadata: [self, #file, #function, #line])
        }

        let networkPath = "\(NetworkPath.media.rawValue)/\(Strings.defaultImageName).\(MediaFileExtension.image(.jpeg).rawValue)"
        let localPath = fileManager.documentsDirectoryURL.appending(path: networkPath)

        if let exception = fileManager.createFile(
            atPath: localPath,
            data: data
        ) {
            return exception
        } else if let exception = await messageDeliveryService.sendMediaMessage(.init(
            localPath,
            name: Strings.defaultImageName,
            fileExtension: .image(.jpeg)
        )) {
            return exception
        }

        return nil
    }

    // MARK: - Process & Send Video

    private func processAndSendVideo(_ url: URL) async -> Exception? {
        let networkPath = "\(NetworkPath.media.rawValue)/\(Strings.defaultVideoName).\(MediaFileExtension.video(.mp4).rawValue)"
        let localPath = fileManager.documentsDirectoryURL.appending(path: networkPath)

        if let exception = await compressVideo(at: url, outputURL: localPath) {
            return exception
        }

        let getThumbnailImageResult = await getThumbnailImage(
            localPath,
            contentType: .video(.mp4)
        )

        switch getThumbnailImageResult {
        case let .success(image):
            guard let imageData = image.dataCompressed(toKB: Int(Floats.imageCompressionSizeKB)),
                  let thumbnailPath = localPath.thumbnailPath else {
                return .init("Failed to process thumbnail data.", metadata: [self, #file, #function, #line])
            }

            if let exception = fileManager.createFile(
                atPath: thumbnailPath,
                data: imageData
            ) {
                return exception
            }

            if let exception = await messageDeliveryService.sendMediaMessage(.init(
                localPath,
                name: Strings.defaultVideoName,
                fileExtension: .video(.mp4)
            )) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Auxiliary

    private func compressVideo(
        at urlPath: URL,
        outputURL: URL
    ) async -> Exception? {
        let urlAsset = AVURLAsset(url: urlPath, options: nil)

        guard let exportSession = AVAssetExportSession(
            asset: urlAsset,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            return .init(
                "Failed to create export session.",
                metadata: [self, #file, #function, #line]
            )
        }

        if fileManager.fileExists(atPath: outputURL.path()) {
            do {
                try fileManager.removeItem(at: outputURL)
            } catch {
                return .init(error, metadata: [self, #file, #function, #line])
            }
        }

        exportSession.outputFileType = .mp4
        exportSession.outputURL = outputURL

        return await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                guard let error = exportSession.error else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: .init(error, metadata: [self, #file, #function, #line]))
            }
        }
    }

    private func getThumbnailImage(
        _ url: URL,
        contentType: MediaFileExtension
    ) async -> Callback<UIImage, Exception> {
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
                let image = try await qlThumbnailGenerator.generateBestRepresentation(for: request)
                return .success(image.uiImage)
            } catch {
                return .failure(.init(error, metadata: [self, #file, #function, #line]))
            }

        case .video:
            let assetImageGenerator = AVAssetImageGenerator(asset: .init(url: url))
            assetImageGenerator.appliesPreferredTrackTransform = true

            do {
                let cgImage = try assetImageGenerator.copyCGImage(
                    at: .init(
                        seconds: 1,
                        preferredTimescale: .init(Floats.avAssetImageGeneratorPreferredTimescale)
                    ),
                    actualTime: nil
                )
                return .success(.init(cgImage: cgImage))
            } catch {
                return .failure(.init(error, metadata: [self, #file, #function, #line]))
            }

        default:
            return .failure(.init(
                "Cannot generate thumbnail for specified media file extension.",
                extraParams: ["MediaFileExtensionRawValue": contentType.rawValue],
                metadata: [self, #file, #function, #line]
            ))
        }
    }

    @MainActor
    private func onContentPickerDismissed(_ callback: Callback<ContentPickerResult, Exception>?) async -> Exception? {
        StatusBarStyle.restore()
        guard let callback else { return nil }

        switch callback {
        case let .success(result):
            switch result {
            case let .document(url):
                return await processAndSendDocument(url)

            case let .image(image):
                return await processAndSendImage(image)

            case let .video(url):
                return await processAndSendVideo(url)
            }

        case let .failure(exception):
            return exception
        }
    }

    private func presentCameraPicker() {
        StatusBarStyle.override(.lightContent)
        services.contentPicker.camera.present()
        isPresentingPickerController = true

        services.contentPicker.camera.onDismiss { result in
            Task {
                // FIXME: Should delay this to allow ChatPageViewController.viewWillAppear(_:) to fire.
                self.isPresentingPickerController = false
                if let exception = await self.onContentPickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }

    private func presentDocumentPicker() {
        StatusBarStyle.override(.lightContent)
        services.contentPicker.document.present()
        isPresentingPickerController = true

        services.contentPicker.document.onDismiss { result in
            Task {
                self.isPresentingPickerController = false
                if let exception = await self.onContentPickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }

    private func presentMediaPicker() {
        StatusBarStyle.override(.lightContent)
        services.contentPicker.media.present()
        isPresentingPickerController = true

        services.contentPicker.media.onDismiss { result in
            Task {
                self.isPresentingPickerController = false
                if let exception = await self.onContentPickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }
}

// swiftlint:enable type_body_length
