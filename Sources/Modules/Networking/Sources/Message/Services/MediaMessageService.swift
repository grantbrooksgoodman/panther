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
    ) async throws(Exception) -> MediaFile {
        do {
            return try cachedMediaFile(localPath: localMediaFilePath)
        } catch {
            return try await downloadMediaFile(
                messageID: messageID,
                localPath: localMediaFilePath
            )
        }
    }

    // MARK: - Delete Media Component

    func deleteMediaComponent(
        for messageID: String
    ) async -> Exception? {
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

            guard await (try? multipleMessagesReference(mediaFilePath)) == false else {
                return nil
            }

            do {
                try await networking.storage.deleteItem(
                    at: "\(NetworkPath.media.rawValue)/\(mediaFilePath)"
                )
            } catch {
                exceptions.append(error)
            }

            do {
                try await networking.storage.deleteItem(
                    at: [
                        NetworkPath.media.rawValue,
                        "\(mediaFilePath)-thumbnail.\(MediaFileExtension.image(.jpeg).rawValue)",
                    ].joined(separator: "/")
                )
            } catch {
                if !error.isEqual(to: .Networking.Storage.storageItemDoesNotExist) {
                    exceptions.append(error)
                }
            }
        } catch {
            exceptions.append(error)
        }

        return exceptions.compiledException
    }

    // MARK: - Upload Media Component

    func uploadMediaComponent(
        _ mediaComponent: MediaFile,
        for message: Message
    ) async -> Exception? {
        let pathPrefix = "\(NetworkPath.media.rawValue)/\(mediaComponent.encodedHash.shortened)"
        let relativePath = "\(pathPrefix).\(mediaComponent.fileExtension.rawValue)"
        let thumbnailRelativePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

        if await (try? networking.storage.itemExists(at: relativePath)) == true {
            guard mediaComponent.hasThumbnail,
                  await (try? networking.storage.itemExists(at: thumbnailRelativePath)) == false else {
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

        do {
            try await networking.storage.upload(
                Data.fromURL(mediaComponent.localPathURL),
                metadata: .init(
                    relativePath,
                    contentType: mediaComponent.fileExtension.contentTypeString
                )
            )

            if let exception = fileManager.move(
                fileAt: mediaComponent.localPathURL,
                toPath: fileManager.documentsDirectoryURL.appending(path: relativePath)
            ) {
                return exception
            }

            guard mediaComponent.hasThumbnail,
                  let thumbnailPath = mediaComponent.localPathURL.thumbnailPath else { return nil }

            try await networking.storage.upload(
                Data.fromURL(thumbnailPath),
                metadata: .init(
                    thumbnailRelativePath,
                    contentType: MediaFileExtension.image(.jpeg).contentTypeString
                )
            )

            return fileManager.move(
                fileAt: thumbnailPath,
                toPath: fileManager.documentsDirectoryURL.appending(path: thumbnailRelativePath)
            )
        } catch {
            return error
        }
    }

    // MARK: - Auxiliary

    private func cachedMediaFile(
        localPath: LocalMediaFilePath
    ) throws(Exception) -> MediaFile {
        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            throw Exception(
                "Media message reference has no local copy.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        return mediaFile
    }

    private func downloadMediaFile(
        messageID: String,
        localPath: LocalMediaFilePath
    ) async throws(Exception) -> MediaFile {
        let userInfo = ["MessageID": messageID]

        do {
            try await networking.storage.downloadItem(
                at: localPath.relativePathString,
                to: localPath.localPathURL
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        if let thumbnailPathString = localPath.relativeThumbnailPathString,
           let thumbnailPathURL = localPath.localThumbnailPathURL {
            do {
                try await networking.storage.downloadItem(
                    at: thumbnailPathString,
                    to: thumbnailPathURL
                )
            } catch {
                throw error.appending(userInfo: userInfo)
            }
        }

        guard let mediaFile = MediaFile(localPath.relativePathString) else {
            throw Exception(
                "Failed to generate media file.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        return mediaFile
    }

    private func multipleMessagesReference(
        _ mediaFilePath: String
    ) async throws(Exception) -> Bool {
        try await IntegrityServiceSession.resolve(.returnOnFailure)
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
    }
}
