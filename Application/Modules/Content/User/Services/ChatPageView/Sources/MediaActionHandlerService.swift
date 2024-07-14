//
//  MediaActionHandlerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
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

        let cameraAction: AKAction = .init("Camera") { self.presentCameraPicker() }
        let photosAction: AKAction = .init("Photos") { self.presentMediaPicker() }

        Task {
            await AKActionSheet(actions: [cameraAction, photosAction]).present()
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
        guard url.startAccessingSecurityScopedResource() else {
            return .init("Failed to access security-scoped URL.", metadata: [self, #file, #function, #line])
        }

        var data: Data?

        do {
            data = try Data(contentsOf: url)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        url.stopAccessingSecurityScopedResource()

        guard let data else {
            return .init("Failed to process video.", metadata: [self, #file, #function, #line])
        }

        let path = "\(networkPaths.media)/\(Strings.defaultVideoName).mp4"
        if let exception = fileManager.createFile(
            atPath: fileManager.documentsDirectoryURL.appending(path: path),
            data: data
        ) {
            return exception
        }

        // TODO: Send video message.
        return nil
    }

    // MARK: - Auxiliary

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

        return nil
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
