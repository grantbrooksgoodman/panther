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

    func getMediaComponent(
        messageID: String,
        localMediaFilePath: LocalMediaFilePath
    ) async -> Callback<MediaFile, Exception> {
        switch cachedMediaFile(localPath: localMediaFilePath) {
        case let .success(mediaFile):
            .success(mediaFile)

        case .failure:
            await downloadMediaFile(
                messageID: messageID,
                localPath: localMediaFilePath
            )
        }
    }

    // MARK: - Delete Media Component

    func deleteMediaComponent(for messageID: String) async -> Exception? {
        var exceptions = [Exception]()

        do {
            guard let hostedContentType = try await HostedContentType(
                hostedValue: networking.database.getValues(
                    at: [
                        NetworkPath.messages.rawValue,
                        messageID,
                        Message.SerializableKey.contentType.rawValue,
                    ].joined(separator: "/")
                )
            ) else {
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

            guard await (try? (multipleMessagesReference(mediaFilePath)).get()) == false else { return nil }

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
        } catch {
            exceptions.append(error)
        }

        return exceptions.compiledException
    }

    // MARK: - Upload Media Component

    func uploadMediaComponent(_ mediaComponent: MediaFile, for message: Message) async -> Exception? {
        let pathPrefix = "\(NetworkPath.media.rawValue)/\(mediaComponent.encodedHash.shortened)"
        let relativePath = "\(pathPrefix).\(mediaComponent.fileExtension.rawValue)"
        let thumbnailRelativePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

        if await (try? networking.storage.itemExists(at: relativePath).get()) == true {
            guard mediaComponent.hasThumbnail,
                  await (try? networking.storage.itemExists(at: thumbnailRelativePath).get()) == false else {
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

    private func cachedMediaFile(
        localPath: LocalMediaFilePath
    ) -> Callback<MediaFile, Exception> {
        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            return .failure(.init(
                "Media message reference has no local copy.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
        }

        return .success(mediaFile)
    }

    private func downloadMediaFile(
        messageID: String,
        localPath: LocalMediaFilePath
    ) async -> Callback<MediaFile, Exception> {
        let userInfo = ["MessageID": messageID]

        if let exception = await networking.storage.downloadItem(
            at: localPath.relativePathString,
            to: localPath.localPathURL
        ) {
            return .failure(exception.appending(userInfo: userInfo))
        }

        if let thumbnailPathString = localPath.relativeThumbnailPathString,
           let thumbnailPathURL = localPath.localThumbnailPathURL,
           let exception = await networking.storage.downloadItem(
               at: thumbnailPathString,
               to: thumbnailPathURL
           ) {
            return .failure(exception.appending(userInfo: userInfo))
        }

        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            return .failure(.init(
                "Failed to generate media file.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo))
        }

        return .success(mediaFile)
    }

    private func multipleMessagesReference(_ mediaFilePath: String) async -> Callback<Bool, Exception> {
        let resolveResult = await IntegrityServiceSession.resolve(.returnOnFailure)

        switch resolveResult {
        case let .success(session):
            return .success(
                session
                    .messageData
                    .values
                    .compactMap {
                        HostedContentType(
                            hostedValue: (($0 as? [String: Any])?[
                                Message
                                    .SerializableKey
                                    .contentType
                                    .rawValue
                            ] as? String) ?? ""
                        )?.mediaFilePath
                    }
                    .count(of: mediaFilePath) > 1
            )

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
