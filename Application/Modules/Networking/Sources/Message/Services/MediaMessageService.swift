//
//  MediaMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public struct MediaMessageService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Media Component

    public func getMediaComponent(for message: Message) async -> Callback<Message, Exception> {
        let commonParams = ["MessageID": message.id]
        guard let localMediaFilePath = message.localMediaFilePath else {
            return .failure(.init(
                "Message does not have a media component.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        switch cachedMediaFile(for: message, localPath: localMediaFilePath) {
        case let .success(mediaFile):
            return .success(appendMediaComponent(mediaFile, to: message))

        case .failure:
            let downloadMediaFileResult = await downloadMediaFile(for: message, localPath: localMediaFilePath)

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

        for fileExtension in MediaFileExtension.hostedCases.map(\.rawValue) {
            if let exception = await networking.storage.deleteItem(
                at: "\(NetworkPath.media.rawValue)/\(messageID).\(fileExtension)"
            ) {
                guard !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) else { continue }
                exceptions.append(exception)
            }
        }

        if let exception = await networking.storage.deleteItem(
            at: "\(NetworkPath.media.rawValue)/\(messageID)\(MediaFile.thumbnailImageNameSuffix)"
        ) {
            guard !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) else { return exceptions.compiledException }
            exceptions.append(exception)
        }

        return exceptions.compiledException
    }

    // MARK: - Upload Media Component

    public func uploadMediaComponent(_ mediaComponent: MediaFile, for message: Message) async -> Exception? {
        let pathPrefix = "\(NetworkPath.media.rawValue)/\(message.id)"
        let mediaNetworkPath = "\(pathPrefix).\(mediaComponent.fileExtension.rawValue)"
        let thumbnailNetworkPath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

        let mediaDataFromURLResult = Data.fromURL(mediaComponent.urlPath)

        switch mediaDataFromURLResult {
        case let .success(mediaData):
            if let exception = await networking.storage.upload(
                mediaData,
                metadata: .init(
                    mediaNetworkPath,
                    contentType: mediaComponent.fileExtension.contentTypeString
                )
            ) {
                return exception
            }

            guard mediaComponent.hasThumbnail,
                  let thumbnailPath = mediaComponent.urlPath.thumbnailPath else { return nil }
            let thumbnailDataFromURLResult = Data.fromURL(thumbnailPath)

            switch thumbnailDataFromURLResult {
            case let .success(thumbnailData):
                return await networking.storage.upload(
                    thumbnailData,
                    metadata: .init(
                        thumbnailNetworkPath,
                        contentType: MediaFileExtension.image(.jpeg).contentTypeString
                    )
                )

            case let .failure(exception):
                return exception
            }

        case let .failure(exception):
            return exception
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
            contentType: .media(mediaComponent.fileExtension),
            richContent: .media(mediaComponent),
            translationReferences: message.translationReferences,
            translations: message.translations,
            readDate: message.readDate,
            sentDate: message.sentDate
        )
    }

    private func cachedMediaFile(
        for message: Message,
        localPath: LocalMediaFilePath
    ) -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let mediaFile = MediaFile(localPath.localPathURL) else {
            return .failure(.init(
                "Media message reference has no local copy.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(mediaFile)
    }

    private func downloadMediaFile(
        for message: Message,
        localPath: LocalMediaFilePath
    ) async -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        if let exception = await networking.storage.downloadItem(
            at: localPath.networkPathString,
            to: localPath.localPathURL
        ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        if let thumbnailNetworkPathString = localPath.thumbnailNetworkPathString,
           let thumbnailLocalPathURL = localPath.thumbnailLocalPathURL,
           let exception = await networking.storage.downloadItem(
               at: thumbnailNetworkPathString,
               to: thumbnailLocalPathURL
           ) {
            return .failure(exception.appending(extraParams: commonParams))
        }

        guard let mediaFile = MediaFile(localPath.localPathURL) else {
            return .failure(.init(
                "Failed to generate media file.",
                metadata: [self, #file, #function, #line]
            ).appending(extraParams: commonParams))
        }

        return .success(mediaFile)
    }
}
