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

/// The service that uploads, downloads, and deletes media message content.
struct MediaMessageService {
    // MARK: - Dependencies

    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Get Media Component

    /// Returns the media file for the given message, using the local copy when available and
    /// downloading it otherwise.
    ///
    /// - Note: A downloaded plain-text document payload is LZFSE-decompressed in place before the
    ///   media file is returned, so the local file is always the plain text the app expects.
    ///
    /// - Parameters:
    ///   - messageID: The identifier of the message.
    ///   - localMediaFilePath: The local file paths for the message's media.
    ///
    /// - Returns: The media file.
    ///
    /// - Throws: An `Exception` if the media cannot be resolved or downloaded.
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

    /// Deletes the media content – and its thumbnail – for the given message from remote storage.
    ///
    /// The content is preserved when it is still referenced by other messages, or when the
    /// message is not a media message.
    ///
    /// - Parameter messageID: The identifier of the message.
    ///
    /// - Throws: An `Exception` if the content type cannot be resolved or deletion fails.
    func deleteMediaComponent(
        for messageID: String
    ) async throws(Exception) {
        var exceptions = [Exception]()

        do throws(Exception) {
            guard let hostedContentType = try await HostedContentType(
                hostedValue: networking.database.getValues(
                    at: [
                        NetworkPath.messages.rawValue,
                        messageID,
                        Message.SerializableKey.contentType.rawValue,
                    ].joined(separator: "/")
                )
            ) else {
                throw Exception(
                    "Failed to resolve hosted content type.",
                    metadata: .init(sender: self)
                )
            }

            guard hostedContentType.isMedia else { return }
            guard let mediaFilePath = hostedContentType.mediaFilePath else {
                throw Exception(
                    "Failed to resolve media file path.",
                    metadata: .init(sender: self)
                )
            }

            guard await (try? multipleMessagesReference(
                mediaFilePath
            )) == false else { return }

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

        if let exception = exceptions.compiledException {
            throw exception
        }
    }

    // MARK: - Upload Media Component

    /// Uploads the given media file and its thumbnail for the given message.
    ///
    /// The file and its thumbnail are uploaded concurrently – each skipped if already present in
    /// remote storage – and the local files are moved into their permanent locations afterward.
    ///
    /// - Note: Plain-text document payloads are LZFSE-compressed before upload; every other kind
    ///   is uploaded unchanged. The local file is always left uncompressed.
    ///
    /// - Parameters:
    ///   - mediaComponent: The media file to upload.
    ///   - message: The message the media belongs to.
    ///
    /// - Throws: An `Exception` if an upload fails.
    func uploadMediaComponent(
        _ mediaComponent: MediaFile,
        for message: Message
    ) async throws(Exception) {
        enum UploadOperation {
            case primary
            case thumbnail
        }

        let pathPrefix = "\(NetworkPath.media.rawValue)/\(mediaComponent.encodedHash.shortened)"
        let relativePath = "\(pathPrefix).\(mediaComponent.fileExtension.rawValue)"
        let thumbnailRelativePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

        func uploadPrimary() async throws(Exception) {
            if await (try? networking.storage.itemExists(at: relativePath)) != true {
                if case .document(.plainText) = mediaComponent.fileExtension {
                    // Hosted plain-text payloads are always LZFSE-compressed,
                    // while the local file stays uncompressed. The timeout is
                    // derived from the uncompressed size and so conservatively
                    // overestimates the compressed transfer.
                    let compressedData: Data
                    do {
                        compressedData = try (Data.fromURL(mediaComponent.localPathURL) as NSData)
                            .compressed(using: .lzfse) as Data
                    } catch let exception as Exception {
                        throw exception
                    } catch {
                        throw Exception(
                            error,
                            metadata: .init(sender: self)
                        )
                    }

                    try await networking.storage.upload(
                        compressedData,
                        metadata: .init(
                            relativePath,
                            contentType: "application/octet-stream"
                        ),
                        timeout: .transferTimeout(forItemAt: mediaComponent.localPathURL)
                    )
                } else {
                    try await networking.storage.upload(
                        fileAt: mediaComponent.localPathURL,
                        metadata: .init(
                            relativePath,
                            contentType: mediaComponent.fileExtension.contentTypeString
                        ),
                        timeout: .transferTimeout(forItemAt: mediaComponent.localPathURL)
                    )
                }
            }

            try fileManager.move(
                fileAt: mediaComponent.localPathURL,
                toPath: fileManager.documentsDirectoryURL.appending(path: relativePath)
            )
        }

        func uploadThumbnail() async throws(Exception) {
            guard mediaComponent.hasThumbnail,
                  let thumbnailPath = mediaComponent.localPathURL.thumbnailPath else { return }

            if await (try? networking.storage.itemExists(at: thumbnailRelativePath)) != true {
                try await networking.storage.upload(
                    fileAt: thumbnailPath,
                    metadata: .init(
                        thumbnailRelativePath,
                        contentType: MediaFileExtension.image(.jpeg).contentTypeString
                    ),
                    timeout: .transferTimeout(forItemAt: thumbnailPath)
                )
            }

            try fileManager.move(
                fileAt: thumbnailPath,
                toPath: fileManager.documentsDirectoryURL.appending(path: thumbnailRelativePath)
            )
        }

        // The primary file and its thumbnail are independent Storage
        // objects; each existence check gates only its own upload.
        try await [
            UploadOperation.primary,
            .thumbnail,
        ].forEachConcurrently { operation throws(Exception) in
            switch operation {
            case .primary: try await uploadPrimary()
            case .thumbnail: try await uploadThumbnail()
            }
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

        // Hosted plain-text payloads are stored LZFSE-compressed;
        // decompress in place so the local file is the plain text
        // the rest of the app expects.
        if case .document(.plainText)? = MediaFileExtension(localPath.localPathURL.pathExtension) {
            do {
                try (Data.fromURL(localPath.localPathURL) as NSData)
                    .decompressed(using: .lzfse)
                    .write(
                        to: localPath.localPathURL,
                        options: .atomic
                    )
            } catch let exception as Exception {
                throw exception.appending(userInfo: userInfo)
            } catch {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo)
            }
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
