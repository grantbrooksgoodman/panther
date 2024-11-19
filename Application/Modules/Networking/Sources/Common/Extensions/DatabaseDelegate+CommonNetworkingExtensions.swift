//
//  DatabaseDelegate+CommonNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public extension DatabaseDelegate {
    func clearTemporaryCaches() {
        CoreDatabaseCache.filter { $0.value.expiryThreshold != .seconds(60) }
    }

    func populateTemporaryCaches() async -> Exception? {
        let resolveResult = await IntegrityServiceSession.resolve(.returnOnFailure)

        switch resolveResult {
        case let .success(session):
            for (key, value) in session.conversationData {
                CoreDatabaseCache.addValue(
                    .init(
                        .now,
                        data: value,
                        expiresAfter: .seconds(60)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.conversations.rawValue)/\(key)"
                )
            }

            for (key, value) in session.messageData {
                CoreDatabaseCache.addValue(
                    .init(
                        .now,
                        data: value,
                        expiresAfter: .seconds(60)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.messages.rawValue)/\(key)"
                )
            }

            for (key, value) in session.translationData {
                for (translationKey, translationValue) in value {
                    CoreDatabaseCache.addValue(
                        .init(
                            .now,
                            data: translationValue,
                            expiresAfter: .seconds(600)
                        ),
                        forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(key)/\(translationKey)"
                    )
                }
            }

            for (key, value) in session.userData {
                CoreDatabaseCache.addValue(
                    .init(
                        .now,
                        data: value,
                        expiresAfter: .seconds(60)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.users.rawValue)/\(key)"
                )
            }

            for (key, value) in session.userNumberHashData {
                CoreDatabaseCache.addValue(
                    .init(
                        .now,
                        data: value,
                        expiresAfter: .seconds(60)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.userNumberHashes.rawValue)/\(key)"
                )
            }

            Logger.log(
                "Established database snapshot.",
                domain: .database,
                metadata: [self, #file, #function, #line]
            )

        case let .failure(exception):
            return exception
        }

        return nil
    }
}
