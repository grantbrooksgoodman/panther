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

struct ClientSession: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.networking.database) private var database: DatabaseDelegate

    // MARK: - Properties

    let entity: EntitySession
    let store: SessionStore
    let sync: SyncSession

    private let _deliveryProgressIndicator = LockIsolated<DeliveryProgressIndicator?>(nil)

    // MARK: - Computed Properties

    var deliveryProgressIndicator: DeliveryProgressIndicator? {
        _deliveryProgressIndicator.wrappedValue
    }

    // MARK: - Init

    fileprivate init(
        entity: EntitySession,
        store: SessionStore,
        sync: SyncSession
    ) {
        self.entity = entity
        self.store = store
        self.sync = sync
    }

    // MARK: - Register Delivery Progress Indicator

    func registerDeliveryProgressIndicator(
        _ deliveryProgressIndicator: DeliveryProgressIndicator
    ) {
        _deliveryProgressIndicator.wrappedValue = deliveryProgressIndicator
    }

    // MARK: - Resolve and Set Language Code

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
            ].joined(separator: "/")
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
