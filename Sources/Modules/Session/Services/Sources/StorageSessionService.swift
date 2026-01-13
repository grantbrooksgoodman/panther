//
//  StorageSessionService.swift
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

struct StorageSessionService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking.storage) private var storage: StorageDelegate

    // MARK: - Current User Data Usage

    func getCurrentUserDataUsage() async -> Callback<Int, Exception> {
        var dataUsageInKilobytes = 0

        if let exception = await populateValuesIfNeeded() {
            return .failure(exception)
        }

        // Size of user object

        let getSizeOfUserObjectResult = getSizeOfUserObject()

        switch getSizeOfUserObjectResult {
        case let .success(sizeOfUserObject): dataUsageInKilobytes += sizeOfUserObject
        case let .failure(exception): return .failure(exception)
        }

        defer { Logger.closeStream(domain: .storageSession) }
        Logger.openStream(
            message: "Size of user object: \(dataUsageInKilobytes)kb",
            domain: .storageSession,
            sender: self
        )

        // Conversation data size

        let getConversationDataSizeResult = getConversationDataSize()

        switch getConversationDataSizeResult {
        case let .success(conversationDataSize):
            Logger.logToStream(
                "Conversation data usage: \(conversationDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += conversationDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Message data size

        let getMessageDataSizeResult = getMessageDataSize()

        switch getMessageDataSizeResult {
        case let .success(messageDataSize):
            Logger.logToStream(
                "Message data usage: \(messageDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += messageDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Translation data size

        let getTranslationDataSizeResult = getTranslationDataSize()

        switch getTranslationDataSizeResult {
        case let .success(translationDataSize):
            Logger.logToStream(
                "Translation data usage: \(translationDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += translationDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Combined audio size

        let getCombinedAudioSizeResult = await getCombinedAudioSize()

        switch getCombinedAudioSizeResult {
        case let .success(combinedAudioSize):
            Logger.logToStream(
                "Audio data usage: \(combinedAudioSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += combinedAudioSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Combined media size

        let getCombinedMediaSizeResult = await getCombinedMediaSize()

        switch getCombinedMediaSizeResult {
        case let .success(combinedMediaSize):
            Logger.logToStream(
                "Media data usage: \(combinedMediaSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += combinedMediaSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Aggregate

        Logger.closeStream(
            domain: .storageSession,
            onLine: #line
        )

        let usageInMB = String(
            format: "%.2f",
            Double(dataUsageInKilobytes) / 1024
        )

        Logger.log(
            "Total data usage: \(dataUsageInKilobytes)kb / \(usageInMB)mb",
            domain: .storageSession,
            sender: self
        )

        return .success(dataUsageInKilobytes)
    }

    // MARK: - Data Size Calculation

    private func getCombinedAudioSize() async -> Callback<Int, Exception> {
        let audioFilePaths = getAudioFilePaths()
        return await totalSizeInKilobytes(of: audioFilePaths)
    }

    private func getCombinedMediaSize() async -> Callback<Int, Exception> {
        let mediaFilePaths = getMediaFilePaths()
        return await totalSizeInKilobytes(of: mediaFilePaths)
    }

    private func getConversationDataSize() -> Callback<Int, Exception> {
        guard let encodedConversationData = currentUser?
            .conversations?
            .map(\.encoded) else {
            return .failure(.init(
                "Failed to resolve encoded conversations.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedConversationData)
    }

    private func getMessageDataSize() -> Callback<Int, Exception> {
        guard let encodedMessageData = currentUser?
            .conversations?
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .map(\.encoded) else {
            return .failure(.init(
                "Failed to resolve encoded messages.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedMessageData)
    }

    private func getSizeOfUserObject() -> Callback<Int, Exception> {
        guard let encodedUserData = currentUser?.encoded else {
            return .failure(.init(
                "Failed to resolve encoded user data.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedUserData)
    }

    private func getTranslationDataSize() -> Callback<Int, Exception> {
        guard let encodedTranslationData = currentUser?
            .conversations?
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .flatMap({ $0.translationReferences ?? [] })
            .compactMap(\.jsonData) else {
            return .failure(.init(
                "Failed to resolve encoded translations.",
                metadata: .init(sender: self)
            ))
        }

        return .success(Int(
            encodedTranslationData.reduce(into: Double()) { partialResult, datum in
                partialResult += Double(datum.count) / 1024
            }
        ))
    }

    // MARK: - Path Enumeration

    private func getAudioFilePaths() -> [String] {
        let localAudioFilePaths = currentUser?
            .conversations?
            .flatMap { $0.messages ?? [] }
            .filter { $0.fromAccountID == User.currentUserID }
            .compactMap(\.localAudioFilePath)

        let inputFilePaths = localAudioFilePaths?.map(\.inputFilePathString)
        let outputFilePaths = localAudioFilePaths?.map(\.outputFilePathString)

        return (inputFilePaths ?? []) + (outputFilePaths ?? []).unique
    }

    private func getMediaFilePaths() -> [String] {
        currentUser?
            .conversations?
            .flatMap { $0.messages ?? [] }
            .filter { $0.fromAccountID == User.currentUserID }
            .compactMap(\.richContent?.mediaComponent?.relativePath)
            .unique ?? []
    }

    // MARK: - Auxiliary

    private func populateValuesIfNeeded() async -> Exception? {
        func satisfiesConstraints(_ conversation: Conversation) -> Bool {
            if !conversation.messageIDs.isBangQualifiedEmpty,
               conversation.messages == nil ||
               conversation.messages?.filteringSystemMessages.isEmpty == true {
                return true
            } else if conversation.messageIDs.count != conversation.messages?.filteringSystemMessages.count {
                return true
            }

            return false
        }

        guard let currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        guard currentUser.conversations == nil ||
            currentUser.conversations?.isEmpty == true ||
            currentUser
            .conversations?
            .visibleForCurrentUser
            .contains(where: { satisfiesConstraints($0) }) == true else {
            return nil
        }

        for conversation in (currentUser.conversations ?? [])
            .visibleForCurrentUser
            .filter({ satisfiesConstraints($0) }) {
            if let exception = await conversation.setMessages() {
                return exception
            }
        }

        return await currentUser.setConversations()
    }

    private func sizeInKilobytes(of data: Any) -> Callback<Int, Exception> {
        guard JSONSerialization.isValidJSONObject(data) else {
            return .failure(.init(
                "Invalid JSON object.",
                userInfo: ["Data": data],
                metadata: .init(sender: self)
            ))
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return .success(Int(Double(jsonData.count) / 1024))
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    private func totalSizeInKilobytes(of items: [String]) async -> Callback<Int, Exception> {
        var totalSizeInKilobytes = 0

        for filePath in items {
            let sizeInKilobytesResult = await storage.sizeInKilobytes(
                ofItemAt: filePath
            )

            switch sizeInKilobytesResult {
            case let .success(sizeInKilobytes): totalSizeInKilobytes += sizeInKilobytes
            case let .failure(exception): return .failure(exception)
            }
        }

        return .success(totalSizeInKilobytes)
    }
}

private extension TranslationReference {
    var jsonData: Data? {
        @Dependency(\.jsonEncoder) var jsonEncoder: JSONEncoder

        do {
            return try jsonEncoder.encode(self)
        } catch {
            Logger.log(.init(
                error,
                userInfo: ["Data": self],
                metadata: .init(sender: self)
            ))
        }

        return nil
    }
}
