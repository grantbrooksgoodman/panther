//
//  ImageMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct ImageMessageService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Public

    public func getImageComponent(for message: Message) async -> Callback<Message, Exception> {
        switch cachedImageFile(for: message) {
        case let .success(imageFile):
            return .success(appendImageComponent(imageFile, to: message))

        case .failure:
            let downloadImageFileResult = await downloadImageFile(for: message)

            switch downloadImageFileResult {
            case let .success(imageFile):
                return .success(appendImageComponent(imageFile, to: message))

            case let .failure(exception):
                return .failure(exception.appending(extraParams: ["MessageID": message.id]))
            }
        }
    }

    public func uploadImageComponent(_ imageComponent: ImageFile, for message: Message) async -> Exception? {
        let fullPath = "\(networking.config.paths.images)/\(message.id).\(imageComponent.fileExtension.rawValue)"

        do {
            let data = try Data(contentsOf: imageComponent.urlPath)
            return await networking.storage.upload(
                data,
                metadata: .init(
                    fullPath,
                    contentType: imageComponent.fileExtension.contentTypeString
                )
            )
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Auxiliary

    private func appendImageComponent(
        _ imageComponent: ImageFile,
        to message: Message
    ) -> Message {
        .init(
            message.id,
            fromAccountID: message.fromAccountID,
            hasAudioComponent: message.hasAudioComponent,
            hasImageComponent: true,
            audioComponents: message.audioComponents,
            image: imageComponent,
            translations: message.translations,
            readDate: message.readDate,
            sentDate: message.sentDate
        )
    }

    private func cachedImageFile(for message: Message) -> Callback<ImageFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localImageFilePath = message.localImageFilePath else {
            return .failure(.init(
                "Message does not have an image component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        guard let imageFile = ImageFile(localImageFilePath.filePathURL) else {
            return .failure(.init(
                "Image message reference has no local copy.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(imageFile)
    }

    private func downloadImageFile(for message: Message) async -> Callback<ImageFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localImageFilePath = message.localImageFilePath else {
            return .failure(.init(
                "Message does not have an image component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        if let exception = await networking.storage.downloadItem(
            at: localImageFilePath.filePathString,
            to: localImageFilePath.filePathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let imageFile = ImageFile(localImageFilePath.filePathURL) else {
            return .failure(.init(
                "Failed to generate image file.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(imageFile)
    }
}
