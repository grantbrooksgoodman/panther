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
    @Dependency(\.networking.config.paths.images) private var imagesPath: String
    @Dependency(\.messageDeliveryService) private var messageDeliveryService: MessageDeliveryService
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

        let takePhotoAction: AKAction = .init("Take photo") {
            self.presentCameraPicker()
        }

        let chooseFromLibraryAction: AKAction = .init("Choose photo from library") {
            self.presentPhotoPicker()
        }

        Task {
            await AKActionSheet(actions: [takePhotoAction, chooseFromLibraryAction]).present()
        }
    }

    // MARK: - Auxiliary

    @MainActor
    private func onImagePickerDismissed(_ result: Callback<UIImage, Exception>?) async -> Exception? {
        StatusBarStyle.restore()
        guard let result else { return nil }

        switch result {
        case let .success(image):
            guard let data = image.dataCompressed(toKB: 1000) else {
                return .init("Failed to compress image.", metadata: [self, #file, #function, #line])
            }

            let path = "\(imagesPath)/\(Strings.defaultImageName).\(ImageFileExtension.png.rawValue)"
            if let exception = fileManager.createFile(
                atPath: fileManager.documentsDirectoryURL.appending(path: path),
                data: data
            ) {
                return exception
            } else if let exception = await messageDeliveryService.sendImageMessage(.init(
                fileManager.documentsDirectoryURL.appending(path: path),
                name: Strings.defaultImageName,
                fileExtension: .png
            )) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    private func presentCameraPicker() {
        StatusBarStyle.override(.lightContent)
        services.mediaPicker.camera.present()

        services.mediaPicker.camera.onDismiss { result in
            Task {
                if let exception = await self.onImagePickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }

    private func presentPhotoPicker() {
        StatusBarStyle.override(.lightContent)
        services.mediaPicker.photo.present()

        services.mediaPicker.photo.onDismiss { result in
            Task {
                if let exception = await self.onImagePickerDismissed(result) {
                    Logger.log(exception, with: .toast())
                }
            }
        }
    }
}
