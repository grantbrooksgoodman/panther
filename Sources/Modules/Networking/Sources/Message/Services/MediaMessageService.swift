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

struct MediaMessageService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Media Component

    func getMediaComponent(for message: Message) async -> Callback<Message, Exception> {
        let commonParams = ["MessageID": message.id]
        guard let localMediaFilePath = message.localMediaFilePath else {
            return .failure(.init(
                "Message does not have a media component.",
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
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
                return .failure(exception.appending(userInfo: ["MessageID": message.id]))
            }
        }
    }

    // MARK: - Delete Media Component

    func deleteMediaComponent(for messageID: String) async -> Exception? {
        var exceptions = [Exception]()

        let getValuesResult = await networking.database.getValues(
            at: "\(NetworkPath.messages.rawValue)/\(messageID)/\(Message.SerializationKeys.contentType.rawValue)"
        )

        switch getValuesResult {
        case let .success(values):
            guard let string = values as? String,
                  let hostedContentType = HostedContentType(hostedValue: string) else {
                return .init(
                    "Failed to resolve hosted content type.",
                    metadata: .init(sender: self)
                )
            }

            guard hostedContentType.isMedia else { return nil }
            guard let mediaFilePath = hostedContentType.mediaFilePath else {
                return .init(
                    "Failed to resolve media file path.",
                    metadata: .init(sender: self)
                )
            }

            if let exception = await networking.storage.deleteItem(
                at: "\(NetworkPath.media.rawValue)/\(mediaFilePath)"
            ) {
                exceptions.append(exception)
            }

            if let exception = await networking.storage.deleteItem(
                at: "\(NetworkPath.media.rawValue)/\(mediaFilePath)-thumbnail.\(MediaFileExtension.image(.jpeg).rawValue)"
            ),
                !exception.isEqual(to: .Networking.Storage.storageItemDoesNotExist) {
                exceptions.append(exception)
            }

        case let .failure(exception):
            exceptions.append(exception)
        }

        return exceptions.compiledException
    }

    // MARK: - Upload Media Component

    func uploadMediaComponent(_ mediaComponent: MediaFile, for message: Message) async -> Exception? {
        let pathPrefix = "\(NetworkPath.media.rawValue)/\(mediaComponent.encodedHash.shortened)"
        let relativePath = "\(pathPrefix).\(mediaComponent.fileExtension.rawValue)"
        let thumbnailRelativePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

        if (try? await networking.storage.itemExists(at: relativePath).get()) == true {
            guard mediaComponent.hasThumbnail,
                  (try? await networking.storage.itemExists(at: thumbnailRelativePath).get()) == false else {
                if let exception = fileManager.move(
                    fileAt: mediaComponent.localPathURL,
                    toPath: fileManager.documentsDirectoryURL.appending(path: relativePath)
                ) {
                    return exception
                }

                guard mediaComponent.hasThumbnail,
                      let thumbnailPath = mediaComponent.localPathURL.thumbnailPath else { return nil }

                return fileManager.move(
                    fileAt: thumbnailPath,
                    toPath: fileManager.documentsDirectoryURL.appending(path: thumbnailRelativePath)
                )
            }
        }

        let mediaDataFromURLResult = Data.fromURL(mediaComponent.localPathURL)

        switch mediaDataFromURLResult {
        case let .success(mediaData):
            if let exception = await networking.storage.upload(
                mediaData,
                metadata: .init(
                    relativePath,
                    contentType: mediaComponent.fileExtension.contentTypeString
                )
            ) {
                return exception
            }

            if let exception = fileManager.move(
                fileAt: mediaComponent.localPathURL,
                toPath: fileManager.documentsDirectoryURL.appending(path: relativePath)
            ) {
                return exception
            }

            guard mediaComponent.hasThumbnail,
                  let thumbnailPath = mediaComponent.localPathURL.thumbnailPath else { return nil }

            let thumbnailDataFromURLResult = Data.fromURL(thumbnailPath)

            switch thumbnailDataFromURLResult {
            case let .success(thumbnailData):
                if let exception = await networking.storage.upload(
                    thumbnailData,
                    metadata: .init(
                        thumbnailRelativePath,
                        contentType: MediaFileExtension.image(.jpeg).contentTypeString
                    )
                ) {
                    return exception
                }

                return fileManager.move(
                    fileAt: thumbnailPath,
                    toPath: fileManager.documentsDirectoryURL.appending(path: thumbnailRelativePath)
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
            contentType: .media(
                id: mediaComponent.encodedHash.shortened,
                extension: mediaComponent.fileExtension
            ),
            richContent: .media(mediaComponent),
            translationReferences: message.translationReferences,
            translations: message.translations,
            readReceipts: message.readReceipts,
            sentDate: message.sentDate
        )
    }

    private func cachedMediaFile(
        for message: Message,
        localPath: LocalMediaFilePath
    ) -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            return .failure(.init(
                "Media message reference has no local copy.",
                isReportable: false,
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        return .success(mediaFile)
    }

    private func downloadMediaFile(
        for message: Message,
        localPath: LocalMediaFilePath
    ) async -> Callback<MediaFile, Exception> {
        let commonParams = ["MessageID": message.id]

        if let exception = await networking.storage.downloadItem(
            at: localPath.relativePathString,
            to: localPath.localPathURL
        ) {
            return .failure(exception.appending(userInfo: commonParams))
        }

        if let thumbnailPathString = localPath.relativeThumbnailPathString,
           let thumbnailPathURL = localPath.localThumbnailPathURL,
           let exception = await networking.storage.downloadItem(
               at: thumbnailPathString,
               to: thumbnailPathURL
           ) {
            return .failure(exception.appending(userInfo: commonParams))
        }

        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            return .failure(.init(
                "Failed to generate media file.",
                metadata: .init(sender: self)
            ).appending(userInfo: commonParams))
        }

        return .success(mediaFile)
    }
}
