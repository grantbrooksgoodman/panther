//
//  MediaActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class MediaActionHandlerService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageViewService.MediaActionHandler

    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
    @Dependency(\.networking.config.paths) private var networkPaths: NetworkPaths
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Attach Media Button Tapped

    public func attachMediaButtonTapped() {
        services.haptics.generateFeedback(.medium)

        let takePhotoAction: AKAction = .init("Take photo") { self.presentCameraPicker() }
        let selectPhotoOrVideoAction: AKAction = .init("Select photo or video") { self.presentMediaPicker() }

        Task {
            await AKActionSheet(
                title: "Attach media",
                actions: [takePhotoAction, selectPhotoOrVideoAction]
            ).present()
        }
    }

    // MARK: - Process & Send Image

    private func processAndSendImage(_ image: UIImage) async -> Exception? {
        guard let data = image.dataCompressed(toKB: 1000) else {
            return .init("Failed to compress image.", metadata: [self, #file, #function, #line])
        }

        let path = "\(networkPaths.media)/\(Strings.defaultImageName).\(MediaFileExtension.image(.png).rawValue)"
        if let exception = fileManager.createFile(
            atPath: fileManager.documentsDirectoryURL.appending(path: path),
            data: data
        ) {
            return exception
        } else if let exception = await messageDeliveryService.sendMediaMessage(.init(
            fileManager.documentsDirectoryURL.appending(path: path),
            name: Strings.defaultImageName,
            fileExtension: .image(.png)
        )) {
            return exception
        }

        return nil
    }

    // MARK: - Process & Send Video

    private func processAndSendVideo(_ url: URL) async -> Exception? {
        let networkPath = "\(networkPaths.media)/\(Strings.defaultVideoName).\(MediaFileExtension.video(.mp4).rawValue)"
        let localPath = fileManager.documentsDirectoryURL.appending(path: networkPath)

        if let exception = await compressVideo(at: url, outputURL: localPath) {
            return exception
        }

        let getThumbnailImageResult = getThumbnailImage(localPath)

        switch getThumbnailImageResult {
        case let .success(image):
            guard let imageData = image.dataCompressed(toKB: 1000),
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

    private func getThumbnailImage(_ url: URL) -> Callback<UIImage, Exception> {
        let assetImageGenerator = AVAssetImageGenerator(asset: .init(url: url))
        assetImageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try assetImageGenerator.copyCGImage(
                at: CMTimeMakeWithSeconds(1.0, preferredTimescale: 600),
                actualTime: nil
            )
            return .success(.init(cgImage: cgImage))
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    @MainActor
    private func onContentPickerDismissed(_ callback: Callback<ContentPickerResult, Exception>?) async -> Exception? {
        StatusBarStyle.restore()
        guard let callback else { return nil }

        switch callback {
        case let .success(result):
            switch result {
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

        services.contentPicker.camera.onDismiss { result in
            Task {
                if let exception = await self.onContentPickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }

    private func presentMediaPicker() {
        StatusBarStyle.override(.lightContent)
        services.contentPicker.media.present()

        services.contentPicker.media.onDismiss { result in
            Task {
                if let exception = await self.onContentPickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }
}
