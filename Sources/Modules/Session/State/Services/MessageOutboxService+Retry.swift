//
//  MessageOutboxService+Retry.swift
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

extension MessageOutboxService {
    // MARK: - Retry Methods

    /// Retries the outbox entry with the given ID.
    func retry(entryID: String) async {
        @Dependency(\.clientSession) var clientSession: ClientSession
        @Dependency(\.networking) var networking: NetworkServices

        guard let candidateRemoteID = networking.database.generateKey(
            for: NetworkPath.messages.rawValue
        ), let entry = claimForRetry(
            id: entryID,
            candidateRemoteID: candidateRemoteID
        ) else { return }

        // Resolve the conversation; remove entry if it no longer exists.
        guard let conversation = clientSession.store.getConversation(
            idKey: entry.conversationIDKey
        ) else {
            remove(id: entryID)
            return Logger.log(
                "Removed outbox entry \(entryID): conversation no longer exists.",
                domain: .messageOutbox,
                sender: self
            )
        }

        // Resolve recipient users from the store, fetching any missing ones.
        var recipientUsers = [User]()
        for userID in entry.recipientUserIDs {
            if let user = clientSession.store.users[userID] {
                recipientUsers.append(user)
            } else {
                do {
                    try await recipientUsers.append(
                        networking.userService.getUser(id: userID)
                    )
                } catch {
                    Logger.log(error)
                }
            }
        }

        guard !recipientUsers.isEmpty else {
            markFailed(id: entryID)
            return Logger.log(
                "Failed to resolve any recipient users for outbox entry \(entryID).",
                domain: .messageOutbox,
                sender: self
            )
        }

        await MainActor.run {
            @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
            inputBarService?.toggleSendingUI(
                on: true,
                clearInputTextViewText: false
            )
        }

        let conversationTuple = (
            value: conversation as Conversation?,
            isPenPalsConversation: entry.isPenPalsConversation
        )

        do {
            try await sendPayload(
                entry.payload,
                presetID: entry.reservedRemoteID,
                toUsers: recipientUsers,
                inConversation: conversationTuple
            )

            remove(id: entryID)
            Logger.log(
                "Retry succeeded for outbox entry \(entryID).",
                domain: .messageOutbox,
                sender: self
            )
        } catch {
            markFailed(id: entryID)
            Logger.log(
                "Retry failed for outbox entry \(entryID).",
                domain: .messageOutbox,
                sender: self
            )
        }

        await MainActor.run {
            @Dependency(\.chatPageViewService.inputBar) var inputBarService: InputBarService?
            inputBarService?.toggleSendingUI(on: false)
        }
    }

    // MARK: - Auxiliary

    private func sendPayload(
        _ payload: OutboxEntry.Payload,
        presetID: String?,
        toUsers users: [User],
        inConversation conversation: (value: Conversation?, isPenPalsConversation: Bool)
    ) async throws {
        @Dependency(\.clientSession) var clientSession: ClientSession

        switch payload {
        case let .audio(inputFileName):
            let fileURL = payloadFileURL(forFileName: inputFileName)
            guard let audioFile = AudioFile(fileURL) else {
                throw Exception(
                    "Failed to reconstruct AudioFile from payload.",
                    metadata: .init(sender: self)
                )
            }

            _ = try await clientSession.entity.message.sendAudioMessage(
                audioFile,
                presetID: presetID,
                toUsers: users,
                inConversation: conversation
            )

        case let .media(fileName, fileExtension):
            _ = try await clientSession.entity.message.sendMediaMessage(
                MediaFile(
                    "outbox/\(fileName)",
                    name: payloadFileURL(
                        forFileName: fileName
                    ).deletingPathExtension().lastPathComponent,
                    fileExtension: fileExtension
                ),
                presetID: presetID,
                toUsers: users,
                inConversation: conversation
            )

        case let .text(text):
            _ = try await clientSession.entity.message.sendTextMessage(
                text,
                presetID: presetID,
                toUsers: users,
                inConversation: conversation
            )
        }
    }

    /// Retries all eligible failed entries, serialized per conversation in FIFO order.
    /// Entries exceeding the auto-retry cap are skipped.
    func retryAllEligible() async {
        let failedEntries = entries.wrappedValue.values
            .filter { $0.state == .failed }
            .sorted { $0.createdDate < $1.createdDate }

        guard !failedEntries.isEmpty else { return }

        // Group by conversation for FIFO-per-conversation serialization.
        let groupedEntries = Dictionary(grouping: failedEntries) { $0.conversationIDKey }

        Logger.log(
            "Auto-retrying \(failedEntries.count) eligible entries across \(groupedEntries.count) conversations.",
            domain: .messageOutbox,
            sender: self
        )

        for (_, conversationEntries) in groupedEntries {
            for entry in conversationEntries {
                guard entry.attemptCount < OutboxEntry.autoRetryCap else {
                    Logger.log(
                        "Skipping outbox entry \(entry.id): attempt count \(entry.attemptCount) exceeds auto-retry cap.",
                        domain: .messageOutbox,
                        sender: self
                    )

                    continue
                }

                await retry(entryID: entry.id)
            }
        }
    }
}
