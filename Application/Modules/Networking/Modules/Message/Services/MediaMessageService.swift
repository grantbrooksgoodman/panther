//
//  MediaMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct MediaMessageService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Get Media Component

    public func getMediaComponent(for message: Message) async -> Callback<Message, Exception> {
        switch cachedMediaFile(for: message) {
        case let .success(mediaFile):
            return .success(appendMediaComponent(mediaFile, to: message))

        case .failure:
            let downloadMediaFileResult = await downloadMediaFile(for: message)

            switch downloadMediaFileResult {
            case let .success(mediaFile):
                return .success(appendMediaComponent(mediaFile, to: message))

            case let .failure(exception):
                return .failure(exception.appending(extraParams: ["MessageID": message.id]))
            }
        }
    }

    // MARK: - Delete Media Component

    public func deleteMediaComponent(for messageID: String) async -> Exception? {
        var exceptions = [Exception]()

        let pathPrefix = "\(networking.config.paths.media)/\(messageID)."
        var fileTypes = [
            MediaFileExtension.image(.png).rawValue,
            MediaFileExtension.video(.mp4).rawValue,
        ]

        for fileType in fileTypes {
            if let exception = await networking.storage.deleteItem(
                at: "\(networking.config.paths.media)/\(messageID).\(fileType)"
            ) {
                guard !exception.isEqual(to: .storageItemDoesNotExist) else { return nil }
                exceptions.append(exception)
            }
        }

        return exceptions.compiledException
    }

    // MARK: - Upload Media Component

    public func uploadMediaComponent(_ mediaComponent: MediaFile, for message: Message) async -> Exception? {
        let fullPath = "\(networking.config.paths.media)/\(message.id).\(mediaComponent.fileExtension.rawValue)"

        do {
            let data = try Data(contentsOf: mediaComponent.urlPath)
            return await networking.storage.upload(
                data,
                metadata: .init(
                    fullPath,
                    contentType: mediaComponent.fileExtension.contentTypeString
                )
            )
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }
    }

    // MARK: - Auxiliary

    private func appendMediaComponent(
        _ mediaComponent: MediaFile,
        to message: Message
    ) -> Message {
        .init(
            message.id,
            fromAccountID: message.fromAccountID,
            contentType: .media,
            richContent: .media(mediaComponent),
            translations: message.translations,
            readDate: message.readDate,
            sentDate: message.sentDate
        )
    }

    private func cachedMediaFile(for message: Message) -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localMediaFilePath = message.localMediaFilePath else {
            return .failure(.init(
                "Message does not have a media component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        guard let mediaFile = MediaFile(localMediaFilePath.localPathURL) else {
            return .failure(.init(
                "Media message reference has no local copy.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(mediaFile)
    }

    private func downloadMediaFile(for message: Message) async -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let localMediaFilePath = message.localMediaFilePath else {
            return .failure(.init(
                "Message does not have a media component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        if let exception = await networking.storage.downloadItem(
            at: localMediaFilePath.networkPathString,
            to: localMediaFilePath.localPathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let mediaFile = MediaFile(localMediaFilePath.localPathURL) else {
            return .failure(.init(
                "Failed to generate media file.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(mediaFile)
    }
}
