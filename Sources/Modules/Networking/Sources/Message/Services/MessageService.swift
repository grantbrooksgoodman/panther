//
//  MessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking
import Translator

/// The service that creates, retrieves, and deletes messages.
///
/// ``MessageService`` builds and writes message nodes, fetches messages by identifier, and
/// deletes messages along with their audio or media content. It delegates content transfer to its
/// ``audio`` and ``media`` sub-services.
struct MessageService {
    // MARK: - Dependencies

    @Dependency(\.timestampDateFormatter) private var dateFormatter: DateFormatter
    @Dependency(\.fileManager.documentsDirectoryURL) private var documentsDirectoryURL: URL
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    /// The service that uploads, downloads, and deletes audio message content.
    let audio: AudioMessageService

    /// The service that uploads, downloads, and deletes media message content.
    let media: MediaMessageService

    private static let coalescer = KeyedCoalescer<String, Message>()

    // MARK: - Init

    /// Creates a message service with the given audio and media services.
    ///
    /// - Parameters:
    ///   - audio: The service that uploads, downloads, and deletes audio message content.
    ///   - media: The service that uploads, downloads, and deletes media message content.
    init(
        audio: AudioMessageService,
        media: MediaMessageService
    ) {
        self.audio = audio
        self.media = media
    }

    // MARK: - Message Creation

    /// Builds a message (generates ID, uploads audio/media to
    /// Storage) without writing the message node to RTDB.
    ///
    /// Callers on the send path use this so the message node
    /// write joins the atomic fan-out in
    /// ``Conversation/willWrite(_:forKey:updating:)``.
    func buildMessage(
        fromAccountID: String,
        presetID: String? = nil,
        inputUploadTask: Task<Callback<Void, Exception>, Never>? = nil,
        richContent: RichMessageContent?,
        sentDate: Date = .now,
        translations: [Translation]?
    ) async throws(Exception) -> Message {
        guard !fromAccountID.isBangQualifiedEmpty,
              !(richContent == nil && translations == nil),
              translations?.isWellFormed ?? true else {
            throw Exception(
                "Passed arguments fail validation.",
                metadata: .init(sender: self)
            )
        }

        guard let id = presetID ?? networking.database.generateKey(
            for: NetworkPath.messages.rawValue
        ) else {
            throw Exception(
                "Failed to generate key for new message.",
                metadata: .init(sender: self)
            )
        }

        var contentType: HostedContentType = .text
        if richContent?.audioComponents != nil {
            contentType = .audio(.m4a)
        } else if let mediaFileID = richContent?.mediaComponent?.encodedHash.shortened,
                  let mediaFileExtension = richContent?.mediaComponent?.fileExtension {
            contentType = .media(
                id: mediaFileID,
                extension: mediaFileExtension
            )
        }

        var mockMessage: Message = .init(
            id,
            fromAccountID: fromAccountID,
            contentType: contentType,
            richContent: richContent,
            translationReferences: translations?.map(\.reference),
            translations: translations,
            readReceipts: nil,
            sentDate: sentDate
        )

        switch mockMessage.contentType {
        case .audio:
            guard let audioComponents = mockMessage.audioComponents else {
                throw Exception(
                    "Failed to find audio components for audio message creation.",
                    metadata: .init(sender: self)
                )
            }

            try await audio.uploadAudioComponents(
                audioComponents,
                for: mockMessage,
                inputUploadTask: inputUploadTask
            )

            // NIT: Can have uploadAudioComponents modify the message.
            mockMessage = mockMessage.replacingRichContent(.audio(
                audioComponents.reduce(into: [AudioMessageReference]()) { partialResult, audioComponent in
                    let inputFileExtension = audioComponent.original.fileExtension.rawValue
                    let outputFileExtension = audioComponent.translated.fileExtension.rawValue

                    let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(mockMessage.id).\(inputFileExtension)"
                    let outputFilePath = "\(audioComponent.translatedDirectoryPath)/\(audioComponent.translated.name).\(outputFileExtension)"

                    partialResult.append(
                        audioComponent.replacingAudioFiles(
                            newInputFileName: mockMessage.id,
                            newInputFileURL: documentsDirectoryURL.appending(path: inputFilePath),
                            newOutputFileURL: documentsDirectoryURL.appending(path: outputFilePath)
                        )
                    )
                }
            ))

            return mockMessage

        case .media:
            guard let mediaComponent = richContent?.mediaComponent else {
                throw Exception(
                    "Failed to find media component for media message creation.",
                    metadata: .init(sender: self)
                )
            }

            let mediaFileID = mediaComponent.encodedHash.shortened
            try await media.uploadMediaComponent(
                mediaComponent,
                for: mockMessage
            )

            // NIT: Can have uploadMediaComponent modify the message.
            mockMessage = mockMessage.replacingRichContent(.media(.init(
                "\(NetworkPath.media.rawValue)/\(mediaFileID).\(mediaComponent.fileExtension.rawValue)",
                name: mediaFileID,
                fileExtension: mediaComponent.fileExtension
            )))

            return mockMessage

        case .text:
            return mockMessage
        }
    }

    /// Builds a message and writes its node to RTDB.
    ///
    /// Use ``buildMessage(fromAccountID:richContent:sentDate:translations:)``
    /// on the send path where the message node write should
    /// join the atomic fan-out instead.
    func createMessage(
        fromAccountID: String,
        richContent: RichMessageContent?,
        sentDate: Date = .now,
        translations: [Translation]?
    ) async throws(Exception) -> Message {
        let message = try await buildMessage(
            fromAccountID: fromAccountID,
            richContent: richContent,
            sentDate: sentDate,
            translations: translations
        )

        try await networking.database.updateChildValues(
            forKey: "\(NetworkPath.messages.rawValue)/\(message.id)",
            with: message.encoded.filter {
                $0.key != Message.SerializableKey.id.rawValue
            }
        )

        return message
    }

    // MARK: - Retrieval by ID

    /// Returns the message with the given identifier.
    ///
    /// - Parameter id: The identifier of the message to fetch.
    ///
    /// - Returns: The message.
    ///
    /// - Throws: An `Exception` if no identifier is provided or the message cannot be fetched or
    ///   decoded.
    func getMessage(
        id: String
    ) async throws(Exception) -> Message {
        let userInfo = ["MessageID": id]

        guard !id.isBangQualifiedEmpty else {
            throw Exception(
                "No ID provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        // Coalesce concurrent fetches of the same message so it is
        // fetched and decoded only once.
        return try await Self.coalescer(id) { () async throws(Exception) -> Message in
            try await fetchMessage(id: id)
        }
    }

    private func fetchMessage(
        id: String
    ) async throws(Exception) -> Message {
        let userInfo = ["MessageID": id]

        var data: [String: Any]
        do {
            data = try await networking.database.getValues(
                at: "\(NetworkPath.messages.rawValue)/\(id)"
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        data["id"] = id
        do {
            return try await Message(from: data)
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    /// Returns the messages with the given identifiers, fetched concurrently.
    ///
    /// - Parameter ids: The identifiers of the messages to fetch.
    ///
    /// - Returns: The messages.
    ///
    /// - Throws: An `Exception` if no identifiers are provided or any message cannot be fetched.
    func getMessages(
        ids: [String]
    ) async throws(Exception) -> [Message] {
        let userInfo = ["MessageIDs": ids]

        guard !ids.isBangQualifiedEmpty else {
            throw Exception(
                "No IDs provided.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        do {
            return try await ids.parallelMap {
                try await getMessage(id: $0)
            }
        } catch {
            throw error.appending(userInfo: userInfo)
        }
    }

    // MARK: - Deletion

    // TODO: Rewrite with Message as the argument for greater efficiency.
    /// Deletes the message with the given identifier, including its audio or media content.
    ///
    /// When a conversation is given, the message is also removed from the conversation's message
    /// index, and – unless suppressed – the conversation's hash and each participant's
    /// conversation token are updated, all in a single atomic operation.
    ///
    /// - Parameters:
    ///   - messageID: The identifier of the message to delete.
    ///   - conversation: The conversation the message belongs to, or `nil` to delete only the
    ///     message node.
    ///   - updateConversationHash: A Boolean value that determines whether to update the
    ///     conversation's hash and tokens.
    ///
    /// - Throws: An `Exception` if deletion fails.
    func deleteMessage(
        id messageID: String,
        in conversation: Conversation? = nil,
        updateConversationHash: Bool = true
    ) async throws(Exception) {
        func deleteMessage() async throws(Exception) {
            var exceptions = [Exception]()

            do {
                try await networking.messageService.audio.deleteInputAudioComponent(
                    for: messageID
                )
            } catch {
                exceptions.append(error)
            }

            do {
                try await networking.messageService.media.deleteMediaComponent(
                    for: messageID
                )
            } catch {
                if !error.isEqual(to: .Networking.Storage.storageItemDoesNotExist) {
                    exceptions.append(error)
                }
            }

            do {
                try await networking.database.setValue(
                    NSNull(),
                    forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
                )
            } catch {
                exceptions.append(error)
            }

            if let exception = exceptions.compiledException {
                throw exception
            }
        }

        guard let conversation else { return try await deleteMessage() }
        try await deleteMessage()

        // Atomic removal from the conversation's message
        // index + hash/token update in one fan-out.
        let conversationPath = [
            NetworkPath.conversations.rawValue,
            conversation.id.key,
        ].joined(separator: "/")

        var updates: [String: Any] = [
            "\(conversationPath)/\(Conversation.SerializableKey.messages.rawValue)/\(messageID)": NSNull(),
        ]

        if updateConversationHash {
            @Dependency(\.timestampDateFormatter) var timestampDateFormatter: DateFormatter

            let updated = conversation
                .copying(messageIDs: conversation.messageIDs.filter { $0 != messageID })
                .copying(metadata: conversation.metadata.copyWith(lastModifiedDate: .now))

            let newHash = updated.encodedHash
            updates["\(conversationPath)/\(Conversation.SerializableKey.encodedHash.rawValue)"] = newHash
            updates["\(conversationPath)/\(Conversation.SerializableKey.metadata.rawValue)/lastModifiedDate"] = timestampDateFormatter.string(from: .now)

            for participant in conversation.participants {
                let tokenPath = [
                    NetworkPath.users.rawValue,
                    participant.userID,
                    User.SerializableKey.conversationIDs.rawValue,
                    conversation.id.key,
                ].joined(separator: "/")

                updates[tokenPath] = newHash
            }
        }

        try await networking.database.commit(updates)
    }

    /// Deletes the messages with the given identifiers concurrently.
    ///
    /// - Parameters:
    ///   - messageIDs: The identifiers of the messages to delete.
    ///   - conversation: The conversation the messages belong to, or `nil` to delete only the
    ///     message nodes.
    ///   - updateConversationHash: A Boolean value that determines whether to update the
    ///     conversation's hash and tokens.
    ///   - failureStrategy: The strategy for how the batch responds to a failure.
    ///
    /// - Throws: An `Exception` if deletion fails.
    func deleteMessages(
        ids messageIDs: [String],
        in conversation: Conversation? = nil,
        updateConversationHash: Bool = true,
        failureStrategy: BatchFailureStrategy = .returnOnFailure
    ) async throws(Exception) {
        try await messageIDs.forEachConcurrently(
            failFast: failureStrategy == .returnOnFailure
        ) { messageID throws(Exception) in
            try await deleteMessage(
                id: messageID,
                in: conversation,
                updateConversationHash: updateConversationHash
            )
        }
    }
}

private extension AudioMessageReference {
    func replacingAudioFiles(
        newInputFileName: String,
        newInputFileURL: URL,
        newOutputFileURL: URL
    ) -> AudioMessageReference {
        .init(
            translation: translation,
            original: .init(
                newInputFileURL,
                name: newInputFileName,
                fileExtension: original.fileExtension,
                contentDuration: original.duration
            ),
            translated: .init(
                newOutputFileURL,
                name: translated.name,
                fileExtension: translated.fileExtension,
                contentDuration: translated.duration
            ),
            translatedDirectoryPath: translatedDirectoryPath
        )
    }
}

private extension Message {
    func replacingRichContent(_ richContent: RichMessageContent?) -> Message {
        .init(
            id,
            fromAccountID: fromAccountID,
            contentType: contentType,
            richContent: richContent,
            translationReferences: translationReferences,
            translations: translations,
            readReceipts: readReceipts,
            sentDate: sentDate
        )
    }
}

// swiftlint:enable file_length type_body_length
