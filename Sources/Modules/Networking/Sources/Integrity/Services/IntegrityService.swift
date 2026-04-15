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

final class IntegrityService: @unchecked Sendable {
    // MARK: - Types

    private struct MediaFileReference {
        /* MARK: Properties */

        fileprivate let mediaFilePath: String
        fileprivate let messageID: String
        fileprivate let thumbnailFilePath: String?

        /* MARK: Init */

        fileprivate init(
            _ messageID: String,
            mediaFilePath: String,
            thumbnailFilePath: String?
        ) {
            self.messageID = messageID
            self.mediaFilePath = mediaFilePath
            self.thumbnailFilePath = thumbnailFilePath
        }
    }

    // MARK: - Dependencies

    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.remoteCache) private var remoteCacheService: RemoteCacheService

    // MARK: - Properties

    private let _session = LockIsolated<IntegrityServiceSession?>(wrappedValue: nil)

    @LockIsolated private var didConfirmUnsafeSessionResolution = false

    // MARK: - Computed Properties

    private var malformedConversationIDKeys: [String] { getMalformedConversationIDKeys() }
    private var malformedMessageIDs: [String] { getMalformedMessageIDs() }
    private var malformedUserIDs: [String] { getMalformedUserIDs() }
    private var session: IntegrityServiceSession { getSession() }

    // MARK: - Resolve Session

    func resolveSession() async -> Exception? {
        await withCheckedContinuation { continuation in
            resolveSession { exception in
                continuation.resume(returning: exception)
            }
        }
    }

    private func resolveSession(
        _ failureStrategy: BatchFailureStrategy = .returnOnFailure,
        completion: @escaping @Sendable (Exception?) -> Void
    ) {
        Task { @MainActor in
            let resolveResult = await IntegrityServiceSession.resolve(failureStrategy)

            switch resolveResult {
            case let .success(session):
                Logger.log(
                    "Resolved\(failureStrategy == .continueOnFailure ? " POTENTIALLY INCOMPLETE" : "") integrity service session.",
                    domain: .dataIntegrity,
                    sender: self
                )
                _session.wrappedValue = session
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

    func pruneDeletedUsers() async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.deletedUsers.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: .init(sender: self))
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

    func pruneInvalidatedCaches() async -> Exception? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.invalidatedCaches.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else {
                return .Networking.typecastFailed("array", metadata: .init(sender: self))
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

    func repairMalformedConversations(_ idKeys: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for conversationIDKey in (idKeys ?? malformedConversationIDKeys).filter({ $0 != .bangQualifiedEmpty }) {
            if idKeys != nil {
                do {
                    _ = try await networking.database.getValues(
                        at: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"
                    ).get()
                } catch let error as Exception {
                    exceptions.append(error)
                    continue
                } catch {
                    exceptions.append(.init(error, metadata: .init(sender: self)))
                    continue
                }
            }

            tookAction = true

            let conversationMessageIDs = (session.conversationData[conversationIDKey] as? [String: Any])
                .flatMap { $0[Conversation.SerializationKeys.messages.rawValue] as? [String] } ?? []

            await withTaskGroup(of: Exception?.self) { taskGroup in
                for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                    guard let dictionary = session.userData[userID] as? [String: Any],
                          var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }
                    conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }
                    let keyPath = "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                    let value = conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings

                    taskGroup.addTask {
                        await self.networking.database.setValue(
                            value,
                            forKey: keyPath
                        )
                    }

                    taskGroup.addTask {
                        await self.remoteCacheService.setCacheStatus(
                            .invalid,
                            userID: userID
                        )
                    }
                }

                taskGroup.addTask {
                    await self.networking.database.setValue(
                        NSNull(),
                        forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"
                    )
                }

                for messageID in conversationMessageIDs {
                    taskGroup.addTask {
                        await self.networking.database.setValue(
                            NSNull(),
                            forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
                        )
                    }
                }

                for await exception in taskGroup {
                    if let exception {
                        exceptions.append(exception)
                    }
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func repairMalformedMessages(_ messageIDs: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for messageID in (messageIDs ?? malformedMessageIDs).filter({ $0 != .bangQualifiedEmpty }) {
            if messageIDs != nil {
                do {
                    _ = try await networking.database.getValues(
                        at: "\(NetworkPath.messages.rawValue)/\(messageID)"
                    ).get()
                } catch let error as Exception {
                    exceptions.append(error)
                    continue
                } catch {
                    exceptions.append(.init(error, metadata: .init(sender: self)))
                    continue
                }
            }

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
        }

        if tookAction,
           let exception = await networking.messageService.deleteMessages(
               ids: messageIDs ?? malformedMessageIDs,
               failureStrategy: .continueOnFailure
           ) {
            exceptions.append(exception)
        }

        return (tookAction, exceptions.compiledException)
    }

    func repairMalformedUsers(_ userIDs: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for userID in (userIDs ?? malformedUserIDs).filter({ $0 != .bangQualifiedEmpty }) {
            tookAction = true
            guard await networking.userService.legacy.convertUser(id: userID) != nil else { continue }

            if userIDs != nil {
                do {
                    _ = try await networking.database.getValues(
                        at: "\(NetworkPath.users.rawValue)/\(userID)"
                    ).get()
                } catch let error as Exception {
                    exceptions.append(error)
                    continue
                } catch {
                    exceptions.append(.init(error, metadata: .init(sender: self)))
                    continue
                }
            }

            // FIXME: Audit this change.
            guard let dictionary = session.userData[userID] as? [String: Any],
                  var conversationIDKeys = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else {
                if let exception = await networking.database.setValue(
                    NSNull(),
                    forKey: "\(NetworkPath.users.rawValue)/\(userID)"
                ) {
                    exceptions.append(exception)
                }
                continue
            }

            conversationIDKeys = conversationIDKeys.compactMap { $0.components(separatedBy: " | ").first }

            if let exception = await repairMalformedConversations(conversationIDKeys).exception {
                exceptions.append(exception)
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(NetworkPath.users.rawValue)/\(userID)"
            ) {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    // MARK: - Broken Data

    func resolveBrokenConversationChain() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        await withTaskGroup(of: Exception?.self) { taskGroup in
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
                let filteredValue = filteredConversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : filteredConversationIDStrings
                let keyPath = "\(NetworkPath.users.rawValue)/\(key)/\(User.SerializationKeys.conversationIDs.rawValue)"

                taskGroup.addTask {
                    await self.networking.database.setValue(
                        filteredValue,
                        forKey: keyPath
                    )
                }
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func resolveBrokenMessageChain() async -> (tookAction: Bool, exception: Exception?) {
        var conversationsToRepair = [String]()
        var exceptions = [Exception]()
        var tookAction = false

        await withTaskGroup(of: Exception?.self) { taskGroup in
            for (conversationIDKey, value) in session.conversationData {
                guard let dictionary = value as? [String: Any],
                      let messageIDs = dictionary[Conversation.SerializationKeys.messages.rawValue] as? [String] else { continue }

                let filteredMessageIDs = messageIDs.filter {
                    session.indices.existingMessageIDs.contains($0)
                }

                guard filteredMessageIDs.count != messageIDs.count else { continue }
                tookAction = true

                guard !filteredMessageIDs.isEmpty else {
                    conversationsToRepair.append(conversationIDKey)
                    continue
                }

                taskGroup.addTask {
                    await self.networking.database.setValue(
                        filteredMessageIDs,
                        forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)/\(Conversation.SerializationKeys.messages.rawValue)"
                    )
                }
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        for conversationIDKey in conversationsToRepair {
            if let exception = await repairMalformedConversations([conversationIDKey]).exception {
                exceptions.append(exception)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func resolveMismatchedParticipants() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var malformedConversationIDKeys = [String]()
        var missingConversationIDsForUserIDs = [String: [String]]()
        var tookAction = false

        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  var participantUserIDs = dictionary[Conversation.SerializationKeys.participants.rawValue] as? [String] else { continue }

            participantUserIDs = participantUserIDs.compactMap { $0.components(separatedBy: " | ").first }

            let usersReferencing = usersReferencing(conversationIDKey: key)
            let usersNotReferencing = participantUserIDs.filter { !usersReferencing.contains($0) }
            let orphaningRatio = Float(usersNotReferencing.count) / Float(participantUserIDs.count)

            if orphaningRatio >= 0.5 {
                malformedConversationIDKeys.append(key)
            } else {
                for userID in usersNotReferencing {
                    missingConversationIDsForUserIDs[userID, default: []].append("\(key) | !")
                }
            }
        }

        for conversationIDKey in malformedConversationIDKeys {
            tookAction = true
            if let exception = await repairMalformedConversations([conversationIDKey]).exception {
                exceptions.append(exception)
            }
        }

        await withTaskGroup(of: Exception?.self) { taskGroup in
            for (userID, missingConversationIDs) in missingConversationIDsForUserIDs {
                guard let dictionary = session.userData[userID] as? [String: Any],
                      var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }

                tookAction = true
                conversationIDStrings.append(contentsOf: missingConversationIDs)
                conversationIDStrings = conversationIDStrings.unique

                taskGroup.addTask {
                    await self.networking.database.setValue(
                        conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings,
                        forKey: "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                    )
                }
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func resolveNoAudioComponentMessages() async -> (tookAction: Bool, exception: Exception?) {
        let audioMessages: [(key: String, translationReferenceStrings: [String])] = session
            .messageData
            .compactMap { key, value in
                guard let dictionary = value as? [String: Any],
                      let contentTypeString = dictionary[
                          Message.SerializationKeys.contentType.rawValue
                      ] as? String,
                      let contentType = HostedContentType(hostedValue: contentTypeString),
                      contentType.isAudio,
                      let translationReferenceStrings = dictionary[
                          Message.SerializationKeys.translationReferences.rawValue
                      ] as? [String] else { return nil }
                return (key, translationReferenceStrings)
            }

        guard !audioMessages.isEmpty else { return (false, nil) }

        var exceptions = [Exception]()
        var tookAction = false

        await withTaskGroup(of: (tookAction: Bool, exceptions: [Exception]).self) { taskGroup in
            for (key, translationReferenceStrings) in audioMessages {
                taskGroup.addTask {
                    var taskExceptions = [Exception]()
                    var taskTookAction = false

                    let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(key).\(MediaFileExtension.audio(.m4a).rawValue)"
                    let contentTypeKeyPath = "\(NetworkPath.messages.rawValue)/\(key)/\(Message.SerializationKeys.contentType.rawValue)"

                    switch await self.networking.storage.itemExists(at: inputFilePath) {
                    case let .success(itemExists):
                        if !itemExists {
                            taskTookAction = true
                            if let exception = await self.networking.database.setValue(
                                HostedContentType.text.rawValue,
                                forKey: contentTypeKeyPath
                            ) {
                                taskExceptions.append(exception)
                            }
                        }

                    case let .failure(exception):
                        taskExceptions.append(exception)
                    }

                    for translationReferenceString in translationReferenceStrings {
                        guard let reference: TranslationReference = .init(translationReferenceString),
                              !reference.languagePair.isIdempotent else { continue }

                        let outputFilePath = [
                            NetworkPath.audioTranslations.rawValue,
                            reference.hostingKey,
                            "\(reference.languagePair.to)-\(AudioService.FileNames.outputM4A)",
                        ].joined(separator: "/")

                        switch await self.networking.storage.itemExists(at: outputFilePath) {
                        case let .success(itemExists):
                            guard !itemExists else { continue }
                            taskTookAction = true

                            if let exception = await self.networking.database.setValue(
                                HostedContentType.text.rawValue,
                                forKey: contentTypeKeyPath
                            ) {
                                taskExceptions.append(exception)
                            }

                        case let .failure(exception):
                            taskExceptions.append(exception)
                        }
                    }

                    return (taskTookAction, taskExceptions)
                }
            }

            for await result in taskGroup {
                if result.tookAction {
                    tookAction = true
                }

                exceptions.append(contentsOf: result.exceptions)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func resolveNoMediaComponentMessages() async -> (tookAction: Bool, exception: Exception?) {
        var mediaFileReferences = [MediaFileReference]()
        for (messageID, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let contentTypeString = dictionary[
                      Message.SerializationKeys.contentType.rawValue
                  ] as? String,
                  let contentType = HostedContentType(hostedValue: contentTypeString),
                  case let .media(
                      id: fileID,
                      extension: fileExtension
                  ) = contentType else { continue }

            let pathPrefix = "\(NetworkPath.media.rawValue)/\(fileID)"
            mediaFileReferences.append(.init(
                messageID,
                mediaFilePath: "\(pathPrefix).\(fileExtension.rawValue)",
                thumbnailFilePath: (fileExtension.isDocument || fileExtension.isVideo)
                    ? "\(pathPrefix)\(MediaFile.thumbnailImageNameSuffix)"
                    : nil
            ))
        }

        guard !mediaFileReferences.isEmpty else { return (false, nil) }
        let uniquePaths: Set<String> = mediaFileReferences.reduce(into: []) { uniquePaths, reference in
            uniquePaths.insert(reference.mediaFilePath)
            if let thumbnailFilePath = reference.thumbnailFilePath {
                uniquePaths.insert(thumbnailFilePath)
            }
        }

        var exceptions = [Exception]()
        var existingPaths = Set<String>()

        await withTaskGroup(of: (
            filePath: String,
            itemExists: Bool,
            exception: Exception?
        ).self) { taskGroup in
            for path in uniquePaths {
                taskGroup.addTask {
                    switch await self.networking.storage.itemExists(at: path) {
                    case let .success(itemExists): (path, itemExists, nil)
                    case let .failure(exception): (path, false, exception)
                    }
                }
            }

            for await itemExistsResult in taskGroup {
                if let exception = itemExistsResult.exception {
                    exceptions.append(exception)
                } else if itemExistsResult.itemExists {
                    existingPaths.insert(itemExistsResult.filePath)
                }
            }
        }

        var malformedMessageIDs = [String]()
        for mediaFileReference in mediaFileReferences {
            let mediaExists = existingPaths.contains(mediaFileReference.mediaFilePath)
            let thumbnailExists = mediaFileReference.thumbnailFilePath.map {
                existingPaths.contains($0)
            } ?? true

            guard !mediaExists || !thumbnailExists else { continue }
            malformedMessageIDs.append(mediaFileReference.messageID)
        }

        guard !malformedMessageIDs.isEmpty else {
            return (false, exceptions.compiledException)
        }

        return await repairMalformedMessages(malformedMessageIDs)
    }

    func resolveNonExistentParticipants() async -> (tookAction: Bool, exception: Exception?) {
        var malformedConversationIDKeys = [String]()
        for (key, value) in session.conversationData {
            guard let dictionary = value as? [String: Any],
                  var participantUserIDs = dictionary[Conversation.SerializationKeys.participants.rawValue] as? [String] else { continue }

            participantUserIDs = participantUserIDs.compactMap { $0.components(separatedBy: " | ").first }
            guard participantUserIDs.contains(where: { !session.userData.keys.contains($0) }) else { continue }

            malformedConversationIDKeys.append(key)
        }

        guard !malformedConversationIDKeys.isEmpty else { return (false, nil) }
        let repairMalformedConversationsResult = await repairMalformedConversations(malformedConversationIDKeys)
        return (true, repairMalformedConversationsResult.exception)
    }

    func resolveNonExistentTranslations() async -> (tookAction: Bool, exception: Exception?) {
        var malformedMessageIDs = [String]()
        var malformedTranslationPaths = Set<String>()

        for (key, value) in session.messageData {
            guard let dictionary = value as? [String: Any],
                  let contentTypeString = dictionary[Message.SerializationKeys.contentType.rawValue] as? String,
                  let contentType = HostedContentType(hostedValue: contentTypeString),
                  contentType.isAudio || contentType == .text,
                  let translationReferenceStrings = dictionary[Message.SerializationKeys.translationReferences.rawValue] as? [String] else { continue }

            var needsRepair = false
            for translationReferenceString in translationReferenceStrings {
                guard let reference = TranslationReference(translationReferenceString) else {
                    needsRepair = true
                    continue
                }

                guard !reference.languagePair.isIdempotent else { continue }

                if let encodedTranslationString = session.translationData[reference.languagePair.string]?[reference.type.key] as? String,
                   !encodedTranslationString.canDecodeTranslationFromComponents {
                    malformedTranslationPaths.insert([
                        NetworkPath.translations.rawValue,
                        reference.languagePair.string,
                        reference.type.key,
                    ].joined(separator: "/"))
                    needsRepair = true
                } else if (session.translationData[reference.languagePair.string]?[reference.type.key] as? String) == nil {
                    needsRepair = true
                }
            }

            if needsRepair {
                malformedMessageIDs.append(key)
            }
        }

        guard !malformedMessageIDs.isEmpty else { return (false, nil) }
        var exceptions = [Exception]()

        await withTaskGroup(of: Exception?.self) { taskGroup in
            for path in malformedTranslationPaths {
                taskGroup.addTask {
                    await self.networking.database.setValue(
                        NSNull(),
                        forKey: path
                    )
                }
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        let repairMalformedMessagesResult = await repairMalformedMessages(malformedMessageIDs)
        if let exception = repairMalformedMessagesResult.exception {
            exceptions.append(exception)
        }

        return (true, exceptions.compiledException)
    }

    func resolveOrphanedMedia() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        let referencedMediaFilePaths = Set(
            session
                .messageData
                .values
                .compactMap {
                    HostedContentType(
                        hostedValue: (($0 as? [String: Any])?[
                            Message
                                .SerializationKeys
                                .contentType
                                .rawValue
                        ] as? String) ?? ""
                    )
                }
                .compactMap(\.mediaFilePath)
        )

        let getDirectoryListingResult = await networking.storage.getDirectoryListing(
            at: NetworkPath.media.rawValue
        )

        switch getDirectoryListingResult {
        case let .success(directoryListing):
            let orphanedMediaFilePaths = Set(
                directoryListing
                    .filePaths
                    .compactMap { $0.components(separatedBy: "/").last }
            ).subtracting(referencedMediaFilePaths)
            guard !orphanedMediaFilePaths.isEmpty else { return (false, nil) }

            await withTaskGroup(of: Exception?.self) { taskGroup in
                for mediaFilePath in orphanedMediaFilePaths {
                    taskGroup.addTask {
                        await self.networking.storage.deleteItem(
                            at: "\(NetworkPath.media.rawValue)/\(mediaFilePath)"
                        )
                    }
                }

                for await exception in taskGroup {
                    if let exception {
                        exceptions.append(exception)
                    }
                }
            }

            return (true, exceptions.compiledException)

        case let .failure(exception):
            return (false, exception)
        }
    }

    func resolveOrphanedMessages() async -> (tookAction: Bool, exception: Exception?) {
        var tookAction = false
        var orphanedMessageIDs = [String]()

        for messageID in session.indices.existingMessageIDs where session.indices.conversationsByMessageID[messageID]?.isEmpty ?? true {
            orphanedMessageIDs.append(messageID)
        }

        guard !orphanedMessageIDs.isEmpty else { return (false, nil) }
        tookAction = true

        if let exception = await networking.messageService.deleteMessages(
            ids: orphanedMessageIDs,
            failureStrategy: .continueOnFailure
        ) {
            return (tookAction, exception)
        }

        return (tookAction, nil)
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
        guard let session = _session.wrappedValue else {
            Logger.log(.init(
                "Referencing unresolved IntegrityServiceSession.",
                metadata: .init(sender: self)
            ))

            return .empty
        }

        return session
    }

    // MARK: - Auxiliary

    /// In practice, only one conversation should ever reference a given message.
    private func conversationsReferencing(messageID: String) -> Set<String> {
        session.indices.conversationsByMessageID[messageID] ?? []
    }

    private func resetHash(conversationIDKey: String) async -> Exception? {
        var exceptions = [Exception]()

        await withTaskGroup(of: Exception?.self) { taskGroup in
            for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                guard let dictionary = session.userData[userID] as? [String: Any],
                      var conversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { continue }
                conversationIDStrings = conversationIDStrings.filter { !$0.hasPrefix(conversationIDKey) }
                conversationIDStrings.append("\(conversationIDKey) | \(String.bangQualifiedEmpty)")
                let keyPath = "\(NetworkPath.users.rawValue)/\(userID)/\(User.SerializationKeys.conversationIDs.rawValue)"
                let value = conversationIDStrings.isBangQualifiedEmpty ? Array.bangQualifiedEmpty : conversationIDStrings

                taskGroup.addTask {
                    await self.networking.database.setValue(
                        value,
                        forKey: keyPath
                    )
                }

                taskGroup.addTask {
                    await self.remoteCacheService.setCacheStatus(
                        .invalid,
                        userID: userID
                    )
                }
            }

            taskGroup.addTask {
                await self.networking.database.setValue(
                    String.bangQualifiedEmpty,
                    forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)/\(Conversation.SerializationKeys.encodedHash.rawValue)"
                )
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        return exceptions.compiledException
    }

    private func usersReferencing(conversationIDKey: String) -> Set<String> {
        session.indices.usersByConversationIDKey[conversationIDKey] ?? []
    }
}

private extension String {
    var canDecodeTranslationFromComponents: Bool {
        let components = components(separatedBy: "–")
        guard components.count == 2,
              components[0].removingPercentEncoding?.isEmpty == false,
              components[1].removingPercentEncoding?.isEmpty == false else { return false }
        return true
    }
}

// swiftlint:enable file_length type_body_length
