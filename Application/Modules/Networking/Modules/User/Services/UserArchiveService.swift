//
//  UserArchiveService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public final class UserArchiveService {
    // MARK: - Properties

    private var archive: [User]?
    @Persistent(.userArchive) private var persistedArchive: [User]?

    // MARK: - Init

    public init() {
        archive = persistedArchive
    }

    // MARK: - Addition

    public func addValue(_ user: User) {
        var values = archive ?? .init()

        guard !values.contains(user) else { return }

        values.removeAll(where: { $0.id.key == user.id.key })
        values.append(.init(
            user.id,
            conversations: user.conversations?.excludingDecodedUsers,
            languageCode: user.languageCode,
            phoneNumber: user.phoneNumber,
            pushTokens: user.pushTokens
        ))

        archive = values
        persistedArchive = archive

        Logger.log(
            .init(
                "Added user to persisted archive.",
                extraParams: ["UserIDKey": user.id.key,
                              "UserIDHash": user.id.hash],
                metadata: [self, #file, #function, #line]
            ),
            domain: .user
        )
    }

    // MARK: - Removal

    public func clearArchive() {
        archive = nil
        persistedArchive = nil
    }

    public func removeValue(idKey: String) {
        archive?.removeAll(where: { $0.id.key == idKey })
        persistedArchive = archive
    }

    // MARK: - Retrieval

    public func getValue(id: UserID) -> User? {
        archive?.first(where: { $0.id == id })
    }

    public func getValue(idKey: String) -> User? {
        archive?.first(where: { $0.id.key == idKey })
    }
}

private extension [Conversation] {
    var excludingDecodedUsers: [Conversation] {
        map {
            .init(
                $0.id,
                messages: $0.messages,
                lastModifiedDate: $0.lastModifiedDate,
                participants: $0.participants,
                users: nil
            )
        }
    }
}
