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

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.commonServices.remoteCache) private var remoteCacheService: RemoteCacheService

    // MARK: - Properties

    private let _session = LockIsolated<IntegrityServiceSession?>(nil)

    @LockIsolated private var didConfirmUnsafeSessionResolution = false

    // MARK: - Computed Properties

    private var malformedConversationIDKeys: [String] {
        getMalformedConversationIDKeys()
    }

    private var malformedMessageIDs: [String] {
        getMalformedMessageIDs()
    }

    private var malformedUserIDs: [String] {
        getMalformedUserIDs()
    }

    private var session: IntegrityServiceSession {
        getSession()
    }

    // MARK: - Resolve Session

    func resolveSession() async throws(Exception) {
        let exception: Exception? = await withCheckedContinuation { continuation in
            resolveSession { exception in
                continuation.resume(returning: exception)
            }
        }

        if let exception {
            throw exception
        }
    }

    private func resolveSession(
        _ failureStrategy: BatchFailureStrategy = .returnOnFailure,
        completion: @escaping @Sendable (Exception?) -> Void
    ) {
        Task { @MainActor in
            do throws(Exception) {
                let session = try await IntegrityServiceSession.resolve(failureStrategy)
                Logger.log(
                    "Resolved\(failureStrategy == .continueOnFailure ? " POTENTIALLY INCOMPLETE" : "") integrity service session.",
                    domain: .dataIntegrity,
                    sender: self
                )
                _session.wrappedValue = session
                completion(nil)
            } catch {
                guard failureStrategy == .returnOnFailure,
                      !error.isEqual(to: .readWriteAccessDisabled),
                      isDeveloperModeEnabled else { return completion(error) }

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

                coreUI.removeOverlay()
                let confirmed = await confirmationAlert.present()
                guard confirmed else { return completion(error) }

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
                    completion(error)
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

    func pruneDeletedUsers() async throws(Exception) {
        let validUserIDs = Set(session.userData.keys)
        try await networking.database.runTransaction(
            at: NetworkPath.deletedUsers.rawValue
        ) { currentValue in
            guard let ids = currentValue as? [String] else { return currentValue }
            let pruned = ids.filter { !validUserIDs.contains($0) }
            return pruned.isEmpty ? NSNull() : pruned
        }
    }

    // MARK: - Prune Invalidated Caches

    func pruneInvalidatedCaches() async throws(Exception) {
        let validUserIDs = Set(session.userData.keys)
        try await networking.database.runTransaction(
            at: NetworkPath.invalidatedCaches.rawValue
        ) { currentValue in
            guard let ids = currentValue as? [String] else { return currentValue }
            let pruned = ids.filter { validUserIDs.contains($0) }
            return pruned.isEmpty ? NSNull() : pruned
        }
    }

    // MARK: - Malformed Data

    func repairMalformedConversations(_ idKeys: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for conversationIDKey in (
            idKeys ?? malformedConversationIDKeys
        ).filter({ $0 != .bangQualifiedEmpty }) {
            if idKeys != nil {
                do {
                    let _: [String: Any] = try await networking.database.getValues(
                        at: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"
                    )
                } catch {
                    exceptions.append(error)
                    continue
                }
            }

            tookAction = true

            let conversationMessageIDs: [String] = {
                guard let dictionary = session.conversationData[conversationIDKey] as? [String: Any] else { return [] }
                if let array = dictionary[Conversation.SerializableKey.messages.rawValue] as? [String] {
                    return array
                } else if let map = dictionary[Conversation.SerializableKey.messages.rawValue] as? [String: Any] {
                    return Array(map.keys)
                }
                return []
            }()

            await withTaskGroup(
                of: Exception?.self
            ) { taskGroup in
                for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                    taskGroup.addTask {
                        do throws(Exception) {
                            let path = [
                                NetworkPath.users.rawValue,
                                userID,
                                User.SerializableKey.conversationIDs.rawValue,
                                conversationIDKey,
                            ].joined(separator: "/")

                            try await self.networking.database.commit([path: NSNull()])
                        } catch {
                            return error
                        }

                        return nil
                    }

                    taskGroup.addTask {
                        do throws(Exception) {
                            try await self.remoteCacheService.setCacheStatus(
                                .invalid,
                                userID: userID
                            )
                        } catch {
                            return error
                        }

                        return nil
                    }
                }

                taskGroup.addTask {
                    do throws(Exception) {
                        try await self.networking.database.setValue(
                            NSNull(),
                            forKey: "\(NetworkPath.conversations.rawValue)/\(conversationIDKey)"
                        )
                    } catch {
                        return error
                    }

                    return nil
                }

                for messageID in conversationMessageIDs {
                    taskGroup.addTask {
                        do throws(Exception) {
                            try await self.networking.database.setValue(
                                NSNull(),
                                forKey: "\(NetworkPath.messages.rawValue)/\(messageID)"
                            )
                        } catch {
                            return error
                        }

                        return nil
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
                    let _: [String: Any] = try await networking.database.getValues(
                        at: "\(NetworkPath.messages.rawValue)/\(messageID)"
                    )
                } catch {
                    exceptions.append(error)
                    continue
                }
            }

            tookAction = true
            for conversationIDKey in conversationsReferencing(messageID: messageID) {
                do throws(Exception) {
                    try await resetHash(
                        conversationIDKey: conversationIDKey
                    )
                } catch {
                    exceptions.append(error)
                }

                guard let dictionary = session.conversationData[conversationIDKey] as? [String: Any] else { continue }

                let rawMessages = dictionary[Conversation.SerializableKey.messages.rawValue]
                let messagesPath = [
                    NetworkPath.conversations.rawValue,
                    conversationIDKey,
                    Conversation.SerializableKey.messages.rawValue,
                ].joined(separator: "/")

                if let map = rawMessages as? [String: Any] {
                    guard map.keys.contains(where: { $0 != messageID }) else {
                        if let exception = await repairMalformedConversations([conversationIDKey]).exception {
                            exceptions.append(exception)
                        }

                        continue
                    }

                    do {
                        try await networking.database.setValue(
                            NSNull(),
                            forKey: "\(messagesPath)/\(messageID)"
                        )
                    } catch {
                        exceptions.append(error)
                    }
                } else if var messageIDs = rawMessages as? [String] {
                    messageIDs = messageIDs.filter { $0 != messageID }

                    guard !messageIDs.isBangQualifiedEmpty else {
                        if let exception = await repairMalformedConversations([conversationIDKey]).exception {
                            exceptions.append(exception)
                        }

                        continue
                    }

                    do {
                        try await networking.database.setValue(
                            messageIDs,
                            forKey: messagesPath
                        )
                    } catch {
                        exceptions.append(error)
                    }
                }
            }
        }

        if tookAction {
            do {
                try await networking.messageService.deleteMessages(
                    ids: messageIDs ?? malformedMessageIDs,
                    failureStrategy: .continueOnFailure
                )
            } catch {
                exceptions.append(error)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func repairMalformedUsers(_ userIDs: [String]? = nil) async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        for userID in (userIDs ?? malformedUserIDs).filter({ $0 != .bangQualifiedEmpty }) {
            tookAction = true
            if userIDs != nil {
                do {
                    let _: [String: Any] = try await networking.database.getValues(
                        at: "\(NetworkPath.users.rawValue)/\(userID)"
                    )
                } catch {
                    exceptions.append(error)
                    continue
                }
            }

            // FIXME: Audit this change.
            guard let dictionary = session.userData[userID] as? [String: Any] else {
                do {
                    try await networking.database.setValue(
                        NSNull(),
                        forKey: "\(NetworkPath.users.rawValue)/\(userID)"
                    )
                } catch {
                    exceptions.append(error)
                }

                continue
            }

            let conversationIDKeys: [String] = if let array = dictionary[User.SerializableKey.conversationIDs.rawValue] as? [String] {
                array.compactMap {
                    $0.components(separatedBy: " | ").first
                }
            } else if let map = dictionary[User.SerializableKey.conversationIDs.rawValue] as? [String: Any] {
                Array(map.keys)
            } else {
                []
            }

            if let exception = await repairMalformedConversations(conversationIDKeys).exception {
                exceptions.append(exception)
            }

            do {
                try await networking.database.setValue(
                    NSNull(),
                    forKey: "\(NetworkPath.users.rawValue)/\(userID)"
                )
            } catch {
                exceptions.append(error)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    // MARK: - Broken Data

    func resolveBrokenConversationChain() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        var tookAction = false

        // Dual-format: map users can be fixed with
        // single-child deletes; legacy array users require
        // a full array rewrite via setValue because the
        // Firebase children are integer indices, not
        // conversation keys.
        var updates = [String: Any]()
        var arrayRewrites = [(path: String, value: [String])]()

        for (userID, value) in session.userData {
            guard let dictionary = value as? [String: Any] else { continue }
            let rawIDs = dictionary[User.SerializableKey.conversationIDs.rawValue]

            if let map = rawIDs as? [String: String] {
                let invalidKeys = map.keys.filter {
                    !session.conversationData.keys.contains($0)
                }

                for key in invalidKeys {
                    let path = [
                        NetworkPath.users.rawValue,
                        userID,
                        User.SerializableKey.conversationIDs.rawValue,
                        key,
                    ].joined(separator: "/")

                    updates[path] = NSNull()
                }

                if !invalidKeys.isEmpty { tookAction = true }
            } else if let array = rawIDs as? [String] {
                let filtered = array.filter { encoded in
                    guard !encoded.isBangQualifiedEmpty,
                          let key = encoded.components(separatedBy: " | ").first else { return true }
                    return session.conversationData.keys.contains(key)
                }

                if filtered.count != array.count {
                    let path = [
                        NetworkPath.users.rawValue,
                        userID,
                        User.SerializableKey.conversationIDs.rawValue,
                    ].joined(separator: "/")

                    arrayRewrites.append((path, filtered))
                    tookAction = true
                }
            }
        }

        if !updates.isEmpty {
            do {
                try await networking.database.commit(updates)
            } catch {
                exceptions.append(error)
            }
        }

        for rewrite in arrayRewrites {
            do {
                try await networking.database.setValue(
                    rewrite.value,
                    forKey: rewrite.path
                )
            } catch {
                exceptions.append(error)
            }
        }

        return (tookAction, exceptions.compiledException)
    }

    func resolveBrokenMessageChain() async -> (tookAction: Bool, exception: Exception?) {
        var arrayRewrites = [(path: String, value: [String])]()
        var conversationsToRepair = [String]()
        var exceptions = [Exception]()
        var mapDeletes = [String: Any]()

        for (conversationIDKey, value) in session.conversationData {
            guard let dictionary = value as? [String: Any] else { continue }

            let rawMessages = dictionary[Conversation.SerializableKey.messages.rawValue]
            let messagesPath = [
                NetworkPath.conversations.rawValue,
                conversationIDKey,
                Conversation.SerializableKey.messages.rawValue,
            ].joined(separator: "/")

            if let map = rawMessages as? [String: Any] {
                let invalidKeys = map.keys.filter {
                    !session.indices.existingMessageIDs.contains($0)
                }

                guard !invalidKeys.isEmpty else { continue }

                guard map.count != invalidKeys.count else {
                    conversationsToRepair.append(conversationIDKey)
                    continue
                }

                for key in invalidKeys {
                    mapDeletes["\(messagesPath)/\(key)"] = NSNull()
                }
            } else if let array = rawMessages as? [String] {
                let filtered = array.filter {
                    session.indices.existingMessageIDs.contains($0)
                }

                guard filtered.count != array.count else { continue }

                guard !filtered.isEmpty else {
                    conversationsToRepair.append(conversationIDKey)
                    continue
                }

                arrayRewrites.append((messagesPath, filtered))
            }
        }

        let tookAction = !arrayRewrites.isEmpty || !mapDeletes.isEmpty || !conversationsToRepair.isEmpty

        if !mapDeletes.isEmpty {
            do {
                try await networking.database.commit(mapDeletes)
            } catch {
                exceptions.append(error)
            }
        }

        do {
            try await arrayRewrites.map(
                failFast: false
            ) {
                try await self.networking.database.setValue(
                    $0.value,
                    forKey: $0.path
                )
            }
        } catch {
            exceptions.append(error)
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
            guard let dictionary = value as? [String: Any] else { continue }

            let participantUserIDs: [String]
            if let array = dictionary[Conversation.SerializableKey.participants.rawValue] as? [String] {
                participantUserIDs = array.compactMap {
                    $0.components(separatedBy: " | ").first
                }
            } else if let map = dictionary[Conversation.SerializableKey.participants.rawValue] as? [String: Any] {
                participantUserIDs = Array(map.keys)
            } else {
                continue
            }

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

        if !missingConversationIDsForUserIDs.isEmpty {
            tookAction = true

            var updates = [String: Any]()
            for (userID, missingConversationIDs) in missingConversationIDsForUserIDs {
                for idString in missingConversationIDs {
                    let key = idString.components(separatedBy: " | ").first ?? idString
                    let hash = idString.components(separatedBy: " | ").last ?? "!"
                    let path = [
                        NetworkPath.users.rawValue,
                        userID,
                        User.SerializableKey.conversationIDs.rawValue,
                        key,
                    ].joined(separator: "/")

                    updates[path] = hash
                }
            }

            do {
                try await networking.database.commit(updates)
            } catch {
                exceptions.append(error)
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
                          Message.SerializableKey.contentType.rawValue
                      ] as? String,
                      let contentType = HostedContentType(hostedValue: contentTypeString),
                      contentType.isAudio,
                      let translationReferenceStrings = dictionary[
                          Message.SerializableKey.translationReferences.rawValue
                      ] as? [String] else { return nil }
                return (key, translationReferenceStrings)
            }

        guard !audioMessages.isEmpty else { return (false, nil) }

        var exceptions = [Exception]()
        var tookAction = false

        await withTaskGroup(
            of: (
                tookAction: Bool,
                exceptions: [Exception]
            ).self
        ) { taskGroup in
            for (key, translationReferenceStrings) in audioMessages {
                taskGroup.addTask {
                    var taskExceptions = [Exception]()
                    var taskTookAction = false

                    let inputFilePath = "\(NetworkPath.audioMessageInputs.rawValue)/\(key).\(MediaFileExtension.audio(.m4a).rawValue)"
                    let contentTypeKeyPath = [
                        NetworkPath.messages.rawValue,
                        key,
                        Message.SerializableKey.contentType.rawValue,
                    ].joined(separator: "/")

                    do throws(Exception) {
                        let itemExists = try await self.networking.storage.itemExists(at: inputFilePath)
                        if !itemExists {
                            taskTookAction = true
                            do throws(Exception) {
                                try await self.networking.database.setValue(
                                    HostedContentType.text.rawValue,
                                    forKey: contentTypeKeyPath
                                )
                            } catch {
                                taskExceptions.append(error)
                            }
                        }
                    } catch {
                        taskExceptions.append(error)
                    }

                    for translationReferenceString in translationReferenceStrings {
                        guard let reference: TranslationReference = .init(translationReferenceString),
                              !reference.languagePair.isIdempotent else { continue }

                        let outputFilePath = [
                            NetworkPath.audioTranslations.rawValue,
                            reference.hostingKey,
                            "\(reference.languagePair.to)-\(AudioService.FileNames.outputM4A)",
                        ].joined(separator: "/")

                        do throws(Exception) {
                            let itemExists = try await self.networking.storage.itemExists(at: outputFilePath)
                            guard !itemExists else { continue }
                            taskTookAction = true

                            do throws(Exception) {
                                try await self.networking.database.setValue(
                                    HostedContentType.text.rawValue,
                                    forKey: contentTypeKeyPath
                                )
                            } catch {
                                taskExceptions.append(error)
                            }
                        } catch {
                            taskExceptions.append(error)
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
                      Message.SerializableKey.contentType.rawValue
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

        await withTaskGroup(
            of: (
                filePath: String,
                itemExists: Bool,
                exception: Exception?
            ).self
        ) { taskGroup in
            for path in uniquePaths {
                taskGroup.addTask {
                    do throws(Exception) {
                        let itemExists = try await self.networking.storage.itemExists(at: path)
                        return (path, itemExists, nil)
                    } catch {
                        return (path, false, error)
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
            guard let dictionary = value as? [String: Any] else { continue }

            let participantUserIDs: [String]
            if let array = dictionary[Conversation.SerializableKey.participants.rawValue] as? [String] {
                participantUserIDs = array.compactMap {
                    $0.components(separatedBy: " | ").first
                }
            } else if let map = dictionary[Conversation.SerializableKey.participants.rawValue] as? [String: Any] {
                participantUserIDs = Array(map.keys)
            } else {
                continue
            }
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
                  let contentTypeString = dictionary[Message.SerializableKey.contentType.rawValue] as? String,
                  let contentType = HostedContentType(hostedValue: contentTypeString),
                  contentType.isAudio || contentType == .text,
                  let translationReferenceStrings = dictionary[Message.SerializableKey.translationReferences.rawValue] as? [String] else { continue }

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

        do {
            try await malformedTranslationPaths.map(
                failFast: false
            ) {
                try await self.networking.database.setValue(
                    NSNull(),
                    forKey: $0
                )
            }
        } catch {
            exceptions.append(error)
        }

        let repairMalformedMessagesResult = await repairMalformedMessages(malformedMessageIDs)
        if let exception = repairMalformedMessagesResult.exception {
            exceptions.append(exception)
        }

        return (true, exceptions.compiledException)
    }

    func resolveOrphanedMedia() async -> (tookAction: Bool, exception: Exception?) {
        var exceptions = [Exception]()
        let contentTypes = session
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
                )
            }

        let referencedMediaFilePaths = contentTypes.reduce(
            into: Set<String>()
        ) { paths, contentType in
            guard let mediaFilePath = contentType.mediaFilePath else { return }
            paths.insert(mediaFilePath)

            if case let .media(
                id: fileID,
                extension: fileExtension
            ) = contentType,
                fileExtension.isDocument ||
                fileExtension.isVideo {
                paths.insert("\(fileID)\(MediaFile.thumbnailImageNameSuffix)")
            }
        }

        let directoryListing: DirectoryListing
        do {
            directoryListing = try await networking.storage.getDirectoryListing(
                at: NetworkPath.media.rawValue
            )
        } catch {
            return (false, error)
        }

        let orphanedMediaFilePaths = Set(
            directoryListing
                .filePaths
                .compactMap { $0.components(separatedBy: "/").last }
        ).subtracting(referencedMediaFilePaths)
        guard !orphanedMediaFilePaths.isEmpty else { return (false, nil) }

        do {
            try await Array(orphanedMediaFilePaths).map(
                failFast: false
            ) {
                try await self.networking.storage.deleteItem(
                    at: "\(NetworkPath.media.rawValue)/\($0)"
                )
            }
        } catch {
            exceptions.append(error)
        }

        return (true, exceptions.compiledException)
    }

    func resolveOrphanedMessages() async -> (tookAction: Bool, exception: Exception?) {
        var tookAction = false
        var orphanedMessageIDs = [String]()

        for messageID in session.indices.existingMessageIDs where session.indices.conversationsByMessageID[messageID]?.isEmpty ?? true {
            orphanedMessageIDs.append(messageID)
        }

        guard !orphanedMessageIDs.isEmpty else { return (false, nil) }
        tookAction = true

        do {
            try await networking.messageService.deleteMessages(
                ids: orphanedMessageIDs,
                failureStrategy: .continueOnFailure
            )
        } catch {
            return (tookAction, error)
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

            dictionary[Conversation.SerializableKey.id.rawValue] = key
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

            dictionary[Message.SerializableKey.id.rawValue] = key
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

            dictionary[User.SerializableKey.id.rawValue] = key
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

    private func resetHash(
        conversationIDKey: String
    ) async throws(Exception) {
        var exceptions = [Exception]()

        await withTaskGroup(
            of: Exception?.self
        ) { taskGroup in
            for userID in usersReferencing(conversationIDKey: conversationIDKey) {
                guard let dictionary = session.userData[userID] as? [String: Any] else { continue }

                let rawIDs = dictionary[User.SerializableKey.conversationIDs.rawValue]

                if rawIDs is [String: Any] {
                    // Map format: set the key directly.
                    let path = [
                        NetworkPath.users.rawValue,
                        userID,
                        User.SerializableKey.conversationIDs.rawValue,
                        conversationIDKey,
                    ].joined(separator: "/")

                    taskGroup.addTask {
                        do throws(Exception) {
                            try await self.networking.database.setValue(
                                String.bangQualifiedEmpty,
                                forKey: path
                            )
                        } catch {
                            return error
                        }

                        return nil
                    }
                } else if var conversationIDStrings = rawIDs as? [String] {
                    // Legacy array format: filter and rewrite.
                    conversationIDStrings = conversationIDStrings.filter {
                        !$0.hasPrefix(conversationIDKey)
                    }

                    conversationIDStrings.append(
                        "\(conversationIDKey) | \(String.bangQualifiedEmpty)"
                    )

                    let value = conversationIDStrings.isBangQualifiedEmpty
                        ? Array.bangQualifiedEmpty
                        : conversationIDStrings

                    taskGroup.addTask {
                        do throws(Exception) {
                            try await self.networking.database.setValue(
                                value,
                                forKey: [
                                    NetworkPath.users.rawValue,
                                    userID,
                                    User.SerializableKey.conversationIDs.rawValue,
                                ].joined(separator: "/")
                            )
                        } catch {
                            return error
                        }

                        return nil
                    }
                } else {
                    continue
                }

                taskGroup.addTask {
                    do throws(Exception) {
                        try await self.remoteCacheService.setCacheStatus(
                            .invalid,
                            userID: userID
                        )
                    } catch {
                        return error
                    }

                    return nil
                }
            }

            taskGroup.addTask {
                do throws(Exception) {
                    try await self.networking.database.setValue(
                        String.bangQualifiedEmpty,
                        forKey: [
                            NetworkPath.conversations.rawValue,
                            conversationIDKey,
                            Conversation.SerializableKey.encodedHash.rawValue,
                        ].joined(separator: "/")
                    )
                } catch {
                    return error
                }

                return nil
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        if let exception = exceptions.compiledException {
            throw exception
        }
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
