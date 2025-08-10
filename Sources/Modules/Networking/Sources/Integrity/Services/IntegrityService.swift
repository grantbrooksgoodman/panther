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
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public final class IntegrityService {
    // MARK: - Dependencies

    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.remoteCache) private var remoteCacheService: RemoteCacheService

    // MARK: - Properties

    private var didConfirmUnsafeSessionResolution = false
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
        await withCheckedContinuation { continuation in
            resolveSession { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    private func resolveSession(
        _ failureStrategy: BatchFailureStrategy = .returnOnFailure,
        completion: @escaping (Exception?) -> Void
    ) {
        Task { @MainActor in
            let resolveResult = await IntegrityServiceSession.resolve(failureStrategy)

            switch resolveResult {
            case let .success(session):
                Logger.log(
                    "Resolved\(failureStrategy == .continueOnFailure ? " POTENTIALLY INCOMPLETE" : "") integrity service session.",
                    domain: .dataIntegrity,
                    metadata: [self, #file, #function, #line]
                )
                _session = session
                completion(nil)

            case let .failure(exception):
                guard failureStrategy == .returnOnFailure,
                      !exception.isEqual(to: .readWriteAccessDisabled),
                      isDeveloperModeEnabled else { return completion(exception) }

                guard !didConfirmUnsafeSessionResolution else {
                    resolveSession(.continueOnFailure) { exception in
                        completion(exception)
                    }
                    return
                }

                let confirmationAlert = AKConfirmationAlert(
                    title: "!! WARNING !!", // swiftlint:disable:next line_length
                    message: "The integrity service session failed to resolve. An attempt can be made to force resolution by accepting incomplete/malformed data.\n\nProceeding with this option may result in irreparable damage to the database. Are you sure you'd like to proceed?",
                    cancelButtonTitle: "Abort",
                    cancelButtonStyle: .preferred,
                    confirmButtonTitle: "Proceed",
                    confirmButtonStyle: .destructive
                )

                confirmationAlert.setTitleAttributes(.init([
                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                    .foregroundColor: UIColor.red,
                ]))

                let confirmed = await confirmationAlert.present()
                guard confirmed else { return completion(exception) }

                let proceedAction: AKAction = .init(
                    "Proceed with Unsafe Resolution",
                    isEnabled: false,
                    style: .destructivePreferred
                ) {
                    Task {
                        self.didConfirmUnsafeSessionResolution = true
                        self.resolveSession(.continueOnFailure) { exception in
                            completion(exception)
                        }
                    }
                }

                let cancelAction: AKAction = .init(
                    Localized(.cancel).wrappedValue,
                    style: .cancel
                ) {
                    completion(exception)
                }

                let actionSheet = AKActionSheet(actions: [proceedAction, cancelAction])
                Task.delayed(by: .seconds(5)) { @MainActor in
                    actionSheet.enableAction(at: 0)
                }

                await actionSheet.present()
            }
        }
    }

    // MARK: - Prune Deleted Users

    public func pruneDeletedUsers() async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.deletedUsers.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            array = array.filter { !session.userData.keys.contains($0) }

            if let exception = await networking.database.setValue(
                array.isBangQualifiedEmpty ? NSNull() : array,
                forKey: NetworkPath.deletedUsers.rawValue
            ) {
                return exception
            }

        case let .failure(exception):
            guard !exception.isEqual(to: .Networking.Database.noValueExists) else { return nil }
            return exception
        }

        return nil
    }

    // MARK: - Prune Invalidated Caches

    public func pruneInvalidatedCaches() async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.invalidatedCaches.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: [self, #file, #function, #line])
            }

            array = array.filter { session.userData.keys.contains($0) }

            if let exception = await networking.database.setValue(
                array.isBangQualifiedEmpty ? NSNull() : array,
                forKey: NetworkPath.invalidatedCaches.rawValue
            ) {
                return exception
            }

        case let .failure(exception):
            guard !exception.isEqual(to: .Networking.Database.noValueExists) else { return nil }
            return exception
        }

        return nil
    }

    // MARK: - Malformed Data

    public func repairMalformedConversations(_ idKeys: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for conversationIDKey in (idKeys ?? malformedConversationIDKeys).filter({ $0 != .bangQualifiedEmpty }) {
            tookAction = true

            for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                guard let dictionary = session.userData[userID] as? [String: Any],
                      var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }

                let keyPath = "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
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
                forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"
            ) {
                exceptions.append(exception)
            }

            guard let dictionary = session.conversationData[conversationIDKey] as? [String: Any],
                  let messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

            for messageID in messageIDs {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
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

        for messageID in (messageIDs ?? malformedMessageIDs).filter({ $0 != .bangQualifiedEmpty }) {
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
                    forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)/\(Conversation.SerializationKeys.messages.rawValue)"
                ) {
                    exceptions.append(exception)
                }
            }

            if let exception = await networking.messageService.deleteMessages(
                ids: messageIDs ?? malformedMessageIDs,
                failureStrategy: .continueOnFailure
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    public func repairMalformedUsers(_ userIDs: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for userID in (userIDs ?? malformedUserIDs).filter({ $0 != .bangQualifiedEmpty }) {
            tookAction = true
            guard await networking.userService.legacy.convertUser(id: userID) != nil else { continue }

            defer {
                Task {
                    if let exception = await networking.database.setValue(
                        NSNull(),
                        forKey: "\(NetworkPath.users.rawValue)/\(userID)"
                    ) {
                        exceptions.append(exception)
                    }
                }
            }

            guard let dictionary = session.userData[userID] as? [String: Any],
                  var conversationIDKeys = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }
            conversationIDKeys = conversationIDKeys.compactMap { $0.components(separatedBy: " | ").first }

            if let exception = await repairMalformedConversations(conversationIDKeys).exception {
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
                forKey: "\(NetworkPath.users.rawValue)/\(key)/\(User.SerializationKeys.conversationIDs.rawValue)"
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
                forKey: "\(NetworkPath.conversations.rawValue)/\(key)/\(Conversation.SerializationKeys.messages.rawValue)"
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
                    guard let dictionary = session.userData[userID] as? [String: Any],
                          var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                    conversationIDStrings.append("\(key) | !")
                    conversationIDStrings = conversationIDStrings.unique
                    tookAction = true

                    if let exception = await networking.database.setValue(
                        conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings,
                        forKey: "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
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
                  let contentType = HostedContentType(hostedValue: contentTypeString),
                  contentType.isAudio,
                  let translationReferenceStrings = dictionary[Message.SerializationKeys.translationReferences.rawValue] as? [String] else { continue }

            let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(key).\(MediaFileExtension.audio(.m4a).rawValue)"
            let inputFileItemExistsResult = await networking.storage.itemExists(at: inputFilePath)

            switch inputFileItemExistsResult {
            case let .success(itemExists):
                if !itemExists {
                    tookAction = true
                    if let exception = await networking.database.setValue(
                        HostedContentType.text.rawValue,
                        forKey: "\(NetworkPath.messages.rawValue)/\(key)/\(Message.SerializationKeys.contentType.rawValue)"
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

                let outputDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(reference.hostingKey)/"
                let outputFilePath = outputDirectoryPath + "\(reference.languagePair.to)-\(AudioService.FileNames.outputM4A)"
                let outputFileItemExistsResult = await networking.storage.itemExists(at: outputFilePath)

                switch outputFileItemExistsResult {
                case let .success(itemExists):
                    guard !itemExists else { continue }

                    tookAction = true
                    if let exception = await networking.database.setValue(
                        HostedContentType.text.rawValue,
                        forKey: "\(NetworkPath.messages.rawValue)/\(key)/\(Message.SerializationKeys.contentType.rawValue)"
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

        var verifiedMediaItemPaths = [String]()
        for (key, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let contentTypeString = dictionary[Message.SerializationKeys.contentType.rawValue] as? String,
                  let contentType = HostedContentType(hostedValue: contentTypeString) else { continue }

            switch contentType {
            case let .media(id: fileID, extension: fileExtension):
                let pathPrefix = "\(NetworkPath.media.rawValue)/\(fileID)"
                let mediaFilePath = "\(pathPrefix).\(fileExtension.rawValue)"
                let mediaThumbnailFilePath = "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"

                var mediaItemExists = false
                var thumbnailItemExists = false

                if verifiedMediaItemPaths.contains(mediaFilePath) {
                    mediaItemExists = true
                } else {
                    let mediaItemExistsResult = await networking.storage.itemExists(at: mediaFilePath)
                    switch mediaItemExistsResult {
                    case let .success(itemExists): mediaItemExists = itemExists
                    case let .failure(exception): exceptions.append(exception)
                    }
                }

                if verifiedMediaItemPaths.contains(mediaThumbnailFilePath) {
                    thumbnailItemExists = true
                } else {
                    let thumbnailItemExistsResult = await networking.storage.itemExists(at: mediaThumbnailFilePath)
                    switch thumbnailItemExistsResult {
                    case let .success(itemExists): thumbnailItemExists = itemExists
                    case let .failure(exception): exceptions.append(exception)
                    }
                }

                if mediaItemExists,
                   !verifiedMediaItemPaths.contains(mediaFilePath) {
                    verifiedMediaItemPaths.append(mediaFilePath)
                }

                if thumbnailItemExists,
                   !verifiedMediaItemPaths.contains(mediaThumbnailFilePath) {
                    verifiedMediaItemPaths.append(mediaThumbnailFilePath)
                }

                guard !mediaItemExists || (!thumbnailItemExists && (fileExtension.isDocument || fileExtension.isVideo)) else { continue }

                tookAction = true
                if let exception = await repairMalformedMessages([key]).exception {
                    exceptions.append(exception)
                }

            default: continue
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
                  let translationReferenceStrings = dictionary[Message.SerializationKeys.translationReferences.rawValue] as? [String] else { continue }

            for translationReferenceString in translationReferenceStrings {
                guard let reference: TranslationReference = .init(translationReferenceString),
                      !reference.languagePair.isIdempotent,
                      session.translationData[reference.languagePair.string]?[reference.type.key] == nil else { continue }

                tookAction = true
                if let exception = await repairMalformedMessages([key]).exception {
                    exceptions.append(exception)
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
                forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
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

            let keyPath = "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
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
            forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)/\(Conversation.SerializationKeys.encodedHash.rawValue)"
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
