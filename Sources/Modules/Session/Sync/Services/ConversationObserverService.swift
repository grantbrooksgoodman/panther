//
//  ConversationObserverService.swift
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

struct ConversationObserverService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    private let observationTask: LockIsolated<Task<Void, Never>?> = .init(nil)

    // MARK: - Observation

    func startObserving(
        conversationIDKey: String
    ) {
        observationTask.projectedValue.withValue {
            $0?.cancel()
            $0 = nil

            Logger.log(
                .init(
                    "Started observing conversation.",
                    isReportable: false,
                    userInfo: ["ConversationIDKey": conversationIDKey],
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )

            $0 = Task {
                await observe(
                    conversationIDKey: conversationIDKey,
                    isRetry: false
                )
            }
        }
    }

    func stopObserving() {
        observationTask.projectedValue.withValue {
            if $0 != nil {
                Logger.log(
                    "Stopped observing conversation.",
                    domain: .conversationObserver,
                    sender: self
                )
            }

            $0?.cancel()
            $0 = nil
        }
    }

    // MARK: - Auxiliary

    private func handleSnapshot(
        _ data: [String: Any],
        conversationIDKey: String
    ) async {
        let data = makeDecodable(
            data,
            conversationIDKey: conversationIDKey
        )

        guard Conversation.canDecode(from: data) else {
            return Logger.log(
                .init(
                    "Received non-decodable conversation snapshot.",
                    userInfo: ["ConversationIDKey": conversationIDKey],
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver,
                with: .toastInPrerelease
            )
        }

        do throws(Exception) {
            let conversation = try await Conversation(from: data)
            let newMessageIDs = Set(
                conversation.messageIDs
            ).subtracting(Set(
                sessionStore.getConversation(
                    idKey: conversationIDKey
                )?.messageIDs ?? []
            ))

            if !newMessageIDs.isEmpty {
                try await conversation.resolveMessages(ids: newMessageIDs)
            }

            sessionStore.upsertConversation(conversation)
        } catch {
            Logger.log(
                .init(
                    error,
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )
        }
    }

    private func makeDecodable(
        _ data: [String: Any],
        conversationIDKey: String
    ) -> [String: Any] {
        let hash = data[
            Conversation.SerializableKey.encodedHash.rawValue
        ] ?? String.bangQualifiedEmpty
        var data = data
        data[
            Conversation.SerializableKey.id.rawValue
        ] = "\(conversationIDKey) | \(hash)"
        return data
    }

    private func observe(
        conversationIDKey: String,
        isRetry: Bool
    ) async {
        do {
            for try await dictionary: [String: Any] in networking.database.observe(
                path: [
                    NetworkPath.conversations.rawValue,
                    conversationIDKey,
                ].joined(separator: "/")
            ) {
                guard !Task.isCancelled else { return }
                await handleSnapshot(
                    dictionary,
                    conversationIDKey: conversationIDKey
                )
            }
        } catch {
            guard !Task.isCancelled else { return }
            Logger.log(
                .init(
                    error,
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )
        }

        // Stream terminated. Retry once after 2 s;
        // the user-node pipeline remains the safety net.
        guard !Task.isCancelled,
              !isRetry else { return }

        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }

        Logger.log(
            .init(
                "Retrying conversation observation after stream termination.",
                isReportable: false,
                userInfo: ["ConversationIDKey": conversationIDKey],
                metadata: .init(sender: self)
            ),
            domain: .conversationObserver
        )

        await observe(
            conversationIDKey: conversationIDKey,
            isRetry: true
        )
    }
}
