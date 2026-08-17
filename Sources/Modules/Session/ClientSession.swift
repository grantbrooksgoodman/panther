//
//  ClientSession.swift
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

/// The container for the current client's session.
///
/// Use ``ClientSession`` to reach the services that make up an active session: the entity services
/// that read and write conversations, messages, and users; the outbox that queues outgoing
/// messages; the in-memory store of resolved content; and the synchronization services that keep a
/// conversation current. Resolve it through the `\.clientSession` dependency.
///
/// - Note: ``ClientSession`` is a value type. Its properties reference shared, reference-like
///   services, so copies of a session observe the same underlying state.
struct ClientSession: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.networking.database) private var database: DatabaseDelegate

    // MARK: - Properties

    /// The container for the session's entity services.
    let entity: EntitySession

    /// The service that queues messages for delivery and retries failed sends.
    let outbox: MessageOutboxService

    /// The in-memory store of the session's conversations, messages, and users.
    let store: SessionStore

    /// The container for the session's conversation synchronization services.
    let sync: SyncSession

    private let _deliveryProgressIndicator = LockIsolated<DeliveryProgressIndicator?>(nil)

    // MARK: - Computed Properties

    /// The indicator that displays the progress of the current message delivery, if one is
    /// registered.
    ///
    /// The value is `nil` until a ``DeliveryProgressIndicator`` is supplied through
    /// ``registerDeliveryProgressIndicator(_:)``, and reflects the most recently registered
    /// indicator thereafter.
    ///
    /// - Note: ``DeliveryProgressIndicator`` is a main-actor type. Access its members only from the
    ///   main actor.
    var deliveryProgressIndicator: DeliveryProgressIndicator? {
        _deliveryProgressIndicator.wrappedValue
    }

    // MARK: - Init

    fileprivate init(
        entity: EntitySession,
        outbox: MessageOutboxService,
        store: SessionStore,
        sync: SyncSession
    ) {
        self.entity = entity
        self.outbox = outbox
        self.store = store
        self.sync = sync
    }

    // MARK: - Register Delivery Progress Indicator

    /// Registers the indicator that displays the progress of the current message delivery.
    ///
    /// Call this method when a screen capable of showing delivery progress becomes active. The
    /// registered indicator replaces any previously registered one and is returned by
    /// ``deliveryProgressIndicator``.
    ///
    /// - Parameter deliveryProgressIndicator: The indicator to register.
    func registerDeliveryProgressIndicator(
        _ deliveryProgressIndicator: DeliveryProgressIndicator
    ) {
        _deliveryProgressIndicator.wrappedValue = deliveryProgressIndicator
    }

    // MARK: - Resolve and Set Language Code

    /// Resolves the current user's language code from the database and applies it to the app.
    ///
    /// Use this method to align the app's active language with the current user's stored preference,
    /// for example after signing in. The resolved code is set on the shared core utilities so that
    /// subsequent localization reflects it.
    ///
    /// - Throws: An ``Exception`` if the current user's identifier has not been set, or if reading
    ///   the language code from the database fails.
    ///
    /// - Important: Call this method only after the current user's identifier has been persisted.
    func resolveAndSetLanguageCode() async throws(Exception) {
        @Persistent(.currentUserID) var currentUserID: String?
        guard let currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        let languageCode: String = try await database.getValues(
            at: [
                NetworkPath.users.rawValue,
                currentUserID,
                User.SerializableKey.languageCode.rawValue,
            ].joined(separator: "/"),
            cacheStrategy: .adaptive
        )

        Logger.log(
            "Setting language code to \(languageCode.englishLanguageName ?? languageCode.uppercased()).",
            domain: .clientSession,
            sender: self
        )

        coreUtilities.setLanguageCode(languageCode)
    }
}

enum ClientSessionDependency: DependencyKey {
    static func resolve(_ values: DependencyValues) -> ClientSession {
        .init(
            entity: .init(
                activity: .init(),
                conversation: .init(),
                message: .init(),
                moderation: .init(),
                reaction: .init(),
                user: .init()
            ),
            outbox: .shared,
            store: .shared,
            sync: .init(conversationObserver: .init())
        )
    }
}

extension DependencyValues {
    var clientSession: ClientSession {
        get { self[ClientSessionDependency.self] }
        set { self[ClientSessionDependency.self] = newValue }
    }
}
