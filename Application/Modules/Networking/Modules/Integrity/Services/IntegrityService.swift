//
//  IntegrityService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class IntegrityService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.remoteCache) private var remoteCacheService: RemoteCacheService

    // MARK: - Properties

    private var _session: IntegrityServiceSession?

    // MARK: - Computed Properties

    private var malformedConversationIDKeys: [String] { getMalformedConversationIDKeys() }
    private var malformedMessageIDs: [String] { getMalformedMessageIDs() }
    private var malformedUserIDs: [String] { getMalformedUserIDs() }
    private var session: IntegrityServiceSession { getSession() }

    // MARK: - Init

    public init() {}

    // MARK: - Resolve Session

    public func resolveSession() async -> Exception? {
        let resolveResult = await IntegrityServiceSession.resolve()

        switch resolveResult {
        case let .success(session):
            Logger.log(
                "Resolved integrity service session.",
                domain: .dataIntegrity,
                metadata: [self, #file, #function, #line]
            )
            _session = session

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Prune Invalidated Caches

    public func pruneInvalidatedCaches() async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: networking.config.paths.invalidatedCaches)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            array = array.filter { session.userData.keys.contains($0) }

            if let exception = await networking.database.setValue(
                array.isBangQualifiedEmpty ? NSNull() : array,
                forKey: networking.config.paths.invalidatedCaches
            ) {
                return exception
            }

        case let .failure(exception):
            return exception
        }

        return nil
    }

    // MARK: - Malformed Data

    public func repairMalformedConversations(_ idKeys: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for conversationIDKey in idKeys ?? malformedConversationIDKeys {
            tookAction = true

            for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                guard let dictionary = session.userData[userID] as? [String: Any],
                      var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }

                let keyPath = "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                if let exception = await networking.database.setValue(
                    conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings,
                    forKey: keyPath
                ) {
                    exceptions.append(exception)
                }

                if let exception = await remoteCacheService.setCacheStatus(.invalid, userID: userID) {
                    exceptions.append(exception)
                }
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.conversations)/\(conversationIDKey)"
            ) {
                exceptions.append(exception)
            }

            guard let dictionary = session.conversationData[conversationIDKey] as? [String: Any],
                  let messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

            for messageID in messageIDs {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: "\(networking.config.paths.messages)/\(messageID)"
                ) {
                    exceptions.append(exception)
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func repairMalformedMessages(_ messageIDs: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for messageID in messageIDs ?? malformedMessageIDs {
            tookAction = true

            for conversationIDKey in conversationsReferencing(messageID: messageID) {
                if let exception = await resetHash(conversationIDKey: conversationIDKey) {
                    exceptions.append(exception)
                }

                guard let dictionary = session.conversationData[conversationIDKey] as? [String: Any],
                      var messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

                messageIDs = messageIDs.filter { $0 != messageID }

                guard !messageIDs.isBangQualifiedEmpty else {
                    if let exception = await repairMalformedConversations([conversationIDKey]).exception {
                        exceptions.append(exception)
                    }
                    continue
                }

                if let exception = await networking.database.setValue(
                    messageIDs,
                    forKey: "\(networking.config.paths.conversations)/\(conversationIDKey)/\(Conversation.SerializationKeys.messages.rawValue)"
                ) {
                    exceptions.append(exception)
                }
            }

            let keyPath = "\(networking.config.paths.messages)/\(messageID)"
            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: keyPath
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func repairMalformedUsers() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for userID in malformedUserIDs {
            tookAction = true
            guard await networking.services.user.legacy.convertUser(id: userID) != nil else { continue }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.users)/\(userID)"
            ) {
                exceptions.append(exception)
            }

            guard let dictionary = session.userData[userID] as? [String: Any] else { continue }

            if let encodedPhoneNumber = dictionary[User.SerializationKeys.phoneNumber.rawValue] as? [String: Any] {
                let decodeResult = await PhoneNumber.decode(from: encodedPhoneNumber)

                switch decodeResult {
                case let .success(phoneNumber):
                    let userNumberHashesPath = "\(networking.config.paths.userNumberHashes)/\(phoneNumber.nationalNumberString.digits.encodedHash)"
                    let getValuesResult = await networking.database.getValues(at: userNumberHashesPath)

                    switch getValuesResult {
                    case let .success(values):
                        guard var array = values as? [String] else {
                            exceptions.append(.typecastFailed("array", metadata: [self, #file, #function, #line]))
                            continue
                        }

                        array = array.filter { $0 != userID }

                        if array.isBangQualifiedEmpty,
                           let exception = await networking.database.setValue(NSNull(), forKey: userNumberHashesPath) {
                            exceptions.append(exception)
                        } else if let exception = await networking.database.setValue(array, forKey: userNumberHashesPath) {
                            exceptions.append(exception)
                        }

                    case let .failure(exception):
                        exceptions.append(exception)
                    }

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

            guard let conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

            if let exception = await repairMalformedConversations(conversationIDStrings).exception {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    // MARK: - Broken Data

    public func resolveBrokenConversationChain() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.userData {
            guard let dictionary = value as? [String: Any],
                  let conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

            var filteredConversationIDStrings = conversationIDStrings.filter { !$0.isBangQualifiedEmpty }
            for conversationIDString in filteredConversationIDStrings where !session
                .conversationData
                .keys
                .contains(where: {
                    $0.hasPrefix(conversationIDString.components(separatedBy: " | ").first ?? conversationIDString)
                }) {
                filteredConversationIDStrings = filteredConversationIDStrings.filter { $0 != conversationIDString }
            }

            guard conversationIDStrings
                .filter({ !$0.isBangQualifiedEmpty })
                .sorted() != filteredConversationIDStrings
                .sorted() else { continue }

            tookAction = true
            if let exception = await networking.database.setValue(
                filteredConversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : filteredConversationIDStrings,
                forKey: "\(networking.config.paths.users)/\(key)/\(User.SerializationKeys.conversationIDs.rawValue)"
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveBrokenMessageChain() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  var messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

            let originalCount = messageIDs.count
            messageIDs = messageIDs.filter { session.messageData.keys.contains($0) }
            guard originalCount != messageIDs.count else { continue }

            tookAction = true
            if let exception = await resetHash(conversationIDKey: key) {
                exceptions.append(exception)
            }

            guard !messageIDs.isBangQualifiedEmpty else {
                if let exception = await repairMalformedConversations([key]).exception {
                    exceptions.append(exception)
                }
                continue
            }

            if let exception = await networking.database.setValue(
                messageIDs,
                forKey: "\(networking.config.paths.conversations)/\(key)/\(Conversation.SerializationKeys.messages.rawValue)"
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveMismatchedParticipants() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  var participantUserIDs = dictionary[Conversation.SerializationKeys.participants.rawValue] as? [String] else { continue }

            participantUserIDs = participantUserIDs.compactMap { $0.components(separatedBy: " | ").first }

            let usersReferencing = usersReferencing(conversationIDKey: key)
            let usersNotReferencing = participantUserIDs.filter { !usersReferencing.contains($0) }
            let orphaningRatio = Float(usersNotReferencing.count) / Float(participantUserIDs.count)

            if orphaningRatio >= 0.5 {
                tookAction = true
                if let exception = await repairMalformedConversations([key]).exception {
                    exceptions.append(exception)
                }
            } else {
                for userID in usersNotReferencing {
                    tookAction = true
                    guard let dictionary = session.userData[userID] as? [String: Any],
                          var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                    conversationIDStrings.append("\(key) | !")
                    conversationIDStrings = conversationIDStrings.unique

                    if let exception = await networking.database.setValue(
                        conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings,
                        forKey: "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                    ) {
                        exceptions.append(exception)
                    }
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveNoAudioComponentMessages() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let contentTypeString = dictionary[Message.SerializationKeys.contentType.rawValue] as? String,
                  let contentType = ContentType(rawValue: contentTypeString),
                  contentType == .audio,
                  let translationReferenceStrings = dictionary[Message.SerializationKeys.translations.rawValue] as? [String] else { continue }

            let inputFilePath = "\(networking.config.paths.audioMessageInputs)/\(key).\(MediaFileExtension.audio(.m4a).rawValue)"
            let inputFileItemExistsResult = await networking.storage.itemExists(at: inputFilePath)

            switch inputFileItemExistsResult {
            case let .success(itemExists):
                if !itemExists {
                    tookAction = true
                    if let exception = await networking.database.setValue(
                        ContentType.text.rawValue,
                        forKey: "\(networking.config.paths.messages)/\(key)/\(Message.SerializationKeys.contentType.rawValue)"
                    ) {
                        exceptions.append(exception)
                    }
                }

            case let .failure(exception):
                exceptions.append(exception)
            }

            for translationReferenceString in translationReferenceStrings {
                guard let reference: TranslationReference = .init(translationReferenceString),
                      !reference.languagePair.isIdempotent else { continue }

                let outputDirectoryPath = "\(networking.config.paths.audioTranslations)/\(reference.hostingKey)/"
                let outputFilePath = outputDirectoryPath + "\(reference.languagePair.to)-\(AudioService.FileNames.outputM4A)"
                let outputFileItemExistsResult = await networking.storage.itemExists(at: outputFilePath)

                switch outputFileItemExistsResult {
                case let .success(itemExists):
                    guard !itemExists else { continue }

                    tookAction = true
                    if let exception = await networking.database.setValue(
                        ContentType.text.rawValue,
                        forKey: "\(networking.config.paths.messages)/\(key)/\(Message.SerializationKeys.contentType.rawValue)"
                    ) {
                        exceptions.append(exception)
                    }

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveNoMediaComponentMessages() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let contentTypeString = dictionary[Message.SerializationKeys.contentType.rawValue] as? String,
                  let contentType = ContentType(rawValue: contentTypeString),
                  contentType == .media else { continue }

            let pathPrefix = "\(networking.config.paths.media)/\(key)"

            let jpegImageFilePath = "\(pathPrefix).\(MediaFileExtension.image(.jpeg).rawValue)"
            let pdfDocumentFilePath = "\(pathPrefix).\(MediaFileExtension.document(.pdf).rawValue)"
            let pngImageFilePath = "\(pathPrefix).\(MediaFileExtension.image(.png).rawValue)"
            let mp4VideoFilePath = "\(pathPrefix).\(MediaFileExtension.video(.mp4).rawValue)"

            let mediaThumbnailFilePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

            var jpegImageFileItemExists = false
            var pdfDocumentFileExists = false
            var pngImageFileItemExists = false
            var mp4VideoFileItemExists = false

            // Check JPEG exists

            let jpegImageFileItemExistsResult = await networking.storage.itemExists(at: jpegImageFilePath)

            switch jpegImageFileItemExistsResult {
            case let .success(itemExists):
                jpegImageFileItemExists = itemExists

            case let .failure(exception):
                exceptions.append(exception)
            }

            // Check PDF exists

            let pdfDocumentFileItemExistsResult = await networking.storage.itemExists(at: pdfDocumentFilePath)

            switch pdfDocumentFileItemExistsResult {
            case let .success(itemExists):
                pdfDocumentFileExists = itemExists

            case let .failure(exception):
                exceptions.append(exception)
            }

            // Check PDF thumbnail exists

            if pdfDocumentFileExists {
                let pdfDocumentThumbnailFileItemExistsResult = await networking.storage.itemExists(at: mediaThumbnailFilePath)

                switch pdfDocumentThumbnailFileItemExistsResult {
                case let .success(itemExists):
                    guard !itemExists else { continue }

                    tookAction = true
                    if let exception = await repairMalformedMessages([key]).exception {
                        exceptions.append(exception)
                    }

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

            // Check PNG exists

            let pngImageFileItemExistsResult = await networking.storage.itemExists(at: pngImageFilePath)

            switch pngImageFileItemExistsResult {
            case let .success(itemExists):
                pngImageFileItemExists = itemExists

            case let .failure(exception):
                exceptions.append(exception)
            }

            guard !pngImageFileItemExists else { continue }

            // Check MP4 exists

            let mp4VideoFileItemExistsResult = await networking.storage.itemExists(at: mp4VideoFilePath)

            switch mp4VideoFileItemExistsResult {
            case let .success(itemExists):
                mp4VideoFileItemExists = itemExists

            case let .failure(exception):
                exceptions.append(exception)
            }

            // Check MP4 thumbnail exists

            if mp4VideoFileItemExists {
                let mp4VideoThumbnailFileItemExistsResult = await networking.storage.itemExists(at: mediaThumbnailFilePath)

                switch mp4VideoThumbnailFileItemExistsResult {
                case let .success(itemExists):
                    guard !itemExists else { continue }

                    tookAction = true
                    if let exception = await repairMalformedMessages([key]).exception {
                        exceptions.append(exception)
                    }

                case let .failure(exception):
                    exceptions.append(exception)
                }
            }

            guard [
                jpegImageFileItemExists,
                pdfDocumentFileExists,
                pngImageFileItemExists,
                mp4VideoFileItemExists,
            ].contains(true) else {
                tookAction = true
                if let exception = await repairMalformedMessages([key]).exception {
                    exceptions.append(exception)
                }

                continue
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveNonExistentParticipants() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  var participantUserIDs = dictionary[Conversation.SerializationKeys.participants.rawValue] as? [String] else { continue }

            participantUserIDs = participantUserIDs.compactMap { $0.components(separatedBy: " | ").first }
            guard participantUserIDs.contains(where: { !session.userData.keys.contains($0) }) else { continue }

            tookAction = true
            if let exception = await repairMalformedConversations([key]).exception {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveNonExistentTranslations() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for (key, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let translationReferenceStrings = dictionary[Message.SerializationKeys.translations.rawValue] as? [String] else { continue }

            for translationReferenceString in translationReferenceStrings {
                guard let reference: TranslationReference = .init(translationReferenceString),
                      !reference.languagePair.isIdempotent else { continue }

                let path = "\(networking.config.paths.translations)/\(reference.languagePair.string)/\(reference.type.key)"
                let getValuesResult = await networking.database.getValues(at: path)

                switch getValuesResult {
                case let .failure(exception):
                    guard exception.isEqual(to: .noValueExists) else {
                        exceptions.append(exception)
                        continue
                    }

                    tookAction = true
                    if let exception = await repairMalformedMessages([key]).exception {
                        exceptions.append(exception)
                    }

                case .success: ()
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func resolveOrphanedMessages() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for messageID in session.messageData.keys where conversationsReferencing(messageID: messageID).isBangQualifiedEmpty {
            tookAction = true
            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(networking.config.paths.messages)/\(messageID)"
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    // MARK: - Computed Property Getters

    private func getMalformedConversationIDKeys() -> [String] {
        var conversationIDKeys = [String]()

        for (key, value) in session.conversationData {
            guard var dictionary = value as? [String: Any] else {
                conversationIDKeys.append(key)
                continue
            }

            dictionary[Conversation.SerializationKeys.id.rawValue] = key
            guard !Conversation.canDecode(from: dictionary) else { continue }

            conversationIDKeys.append(key)
        }

        return conversationIDKeys
    }

    private func getMalformedMessageIDs() -> [String] {
        var messageIDs = [String]()

        for (key, value) in session.messageData {
            guard var dictionary = value as? [String: Any] else {
                messageIDs.append(key)
                continue
            }

            dictionary[Message.SerializationKeys.id.rawValue] = key
            guard !Message.canDecode(from: dictionary) else { continue }

            messageIDs.append(key)
        }

        return messageIDs
    }

    private func getMalformedUserIDs() -> [String] {
        var userIDs = [String]()

        for (key, value) in session.userData {
            guard var dictionary = value as? [String: Any] else {
                userIDs.append(key)
                continue
            }

            dictionary[User.SerializationKeys.id.rawValue] = key
            guard !User.canDecode(from: dictionary) else { continue }

            userIDs.append(key)
        }

        return userIDs
    }

    private func getSession() -> IntegrityServiceSession {
        // swiftlint:disable:next identifier_name
        guard let _session else {
            Logger.log(.init(
                "Referencing unresolved IntegrityServiceSession.",
                metadata: [self, #file, #function, #line]
            ))

            return .empty
        }

        return _session
    }

    // MARK: - Auxiliary

    /// In practice, only one conversation should ever reference a given message.
    private func conversationsReferencing(messageID: String) -> [String] {
        var referencing = [String]()

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  let messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String],
                  messageIDs.contains(messageID) else { continue }

            referencing.append(key)
        }

        return referencing
    }

    private func resetHash(conversationIDKey: String) async -> Exception? {
        var exceptions = [Exception]()

        for userID in usersReferencing(conversationIDKey: conversationIDKey) {
            guard let dictionary = session.userData[userID] as? [String: Any],
                  var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

            conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }
            conversationIDStrings.append("\(conversationIDKey) | \(String.bangQualifiedEmpty)")

            let keyPath = "\(networking.config.paths.users)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
            if let exception = await networking.database.setValue(
                conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings,
                forKey: keyPath
            ) {
                exceptions.append(exception)
            }

            if let exception = await remoteCacheService.setCacheStatus(.invalid, userID: userID) {
                exceptions.append(exception)
            }
        }

        if let exception = await networking.database.setValue(
            String.bangQualifiedEmpty,
            forKey: "\(networking.config.paths.conversations)/\(conversationIDKey)/\(Conversation.SerializationKeys.encodedHash.rawValue)"
        ) {
            exceptions.append(exception)
        }

        return exceptions.compiledException
    }

    private func usersReferencing(conversationIDKey: String) -> [String] {
        var referencing = [String]()

        for (key, value) in session.userData {
            guard let dictionary = value as? [String: Any],
                  let conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String],
                  conversationIDStrings.contains(where: { $0.hasPrefix(conversationIDKey) }) else { continue }

            referencing.append(key)
        }

        return referencing
    }
}

// swiftlint:enable file_length type_body_length
