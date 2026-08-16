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

/// The service that observes a conversation for real-time updates.
///
/// ``ConversationObserverService`` maintains a live observation stream for a single conversation,
/// applying each snapshot to the session store as it arrives. At most one conversation is observed
/// at a time.
struct ConversationObserverService {
    // MARK: - Types

    private struct ObservationState {
        let conversationIDKey: String
        let generation: UUID
        let task: Task<Void, Never>
    }

    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    private let observationState: LockIsolated<ObservationState?> = .init(nil)

    // MARK: - Observation

    /// Returns a Boolean value that indicates whether the given conversation is actively being
    /// observed.
    ///
    /// The observation is considered active while its stream is live or inside its single retry
    /// window. Once the stream has permanently ended, this returns `false`, at which point the
    /// user-node pipeline resumes responsibility.
    ///
    /// - Parameter conversationIDKey: The identifier key of the conversation to check.
    ///
    /// - Returns: `true` if the conversation is actively being observed; otherwise, `false`.
    func isActivelyObserving(_ conversationIDKey: String) -> Bool {
        observationState.wrappedValue?.conversationIDKey == conversationIDKey
    }

    /// Starts observing the given conversation for real-time updates.
    ///
    /// Any conversation currently being observed is stopped first, so at most one conversation is
    /// observed at a time.
    ///
    /// - Parameter conversationIDKey: The identifier key of the conversation to observe.
    func startObserving(
        conversationIDKey: String
    ) {
        observationState.projectedValue.withValue {
            $0?.task.cancel()

            Logger.log(
                .init(
                    "Started observing conversation.",
                    isReportable: false,
                    userInfo: ["ConversationIDKey": conversationIDKey],
                    metadata: .init(sender: self)
                ),
                domain: .conversationObserver
            )

            let generation = UUID()
            $0 = .init(
                conversationIDKey: conversationIDKey,
                generation: generation,
                task: Task {
                    await observe(
                        conversationIDKey: conversationIDKey,
                        isRetry: false
                    )

                    observationState.projectedValue.withValue { state in
                        guard state?.generation == generation else { return }
                        state = nil
                    }
                }
            )
        }
    }

    /// Stops observing the currently observed conversation, if any.
    func stopObserving() {
        observationState.projectedValue.withValue {
            if $0 != nil {
                Logger.log(
                    "Stopped observing conversation.",
                    domain: .conversationObserver,
                    sender: self
                )
            }

            $0?.task.cancel()
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
                    userInfo: [
                        "ConversationIDKey": conversationIDKey,
                        "Data": data,
                    ],
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
                Logger.log(
                    .init(
                        "Resolving \(newMessageIDs.count) new message(s) from observer snapshot.",
                        isReportable: false,
                        userInfo: ["ConversationIDKey": conversationIDKey],
                        metadata: .init(sender: self)
                    ),
                    domain: .conversationObserver
                )

                try await conversation.resolveMessages(ids: newMessageIDs)
            }

            // Received from real-time observer; bypasses RemotelyUpdatable.update.
            sessionStore.upsertConversation(conversation)

            // Backfill users for any participants not yet in the
            // session store. The user-node pipeline normally
            // handles this via resolveUsersOnCurrentUserConversations,
            // but the observer guard makes that path skip this
            // conversation.
            let participantUserIDs = conversation.participants
                .map(\.userID)
                .filter { $0 != User.currentUserID }

            if participantUserIDs.contains(where: {
                sessionStore.users[$0] == nil
            }) {
                Logger.log(
                    .init(
                        "Backfilling missing participant user(s) from observer snapshot.",
                        isReportable: false,
                        userInfo: ["ConversationIDKey": conversationIDKey],
                        metadata: .init(sender: self)
                    ),
                    domain: .conversationObserver
                )

                try await conversation.resolveUsers()
            }
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
