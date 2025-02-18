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
        CoreDatabaseStore.filter { $0.value.expiryThreshold != .seconds(300) }
    }

    func populateTemporaryCaches() async -> Exception? {
        let resolveResult = await IntegrityServiceSession.resolve(.returnOnFailure)

        switch resolveResult {
        case let .success(session):
            for (key, value) in session.conversationData {
                CoreDatabaseStore.addValue(
                    .init(
                        data: value,
                        expiresAfter: .seconds(300)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.conversations.rawValue)/\(key)"
                )
            }

            for (key, value) in session.messageData {
                CoreDatabaseStore.addValue(
                    .init(
                        data: value,
                        expiresAfter: .seconds(300)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.messages.rawValue)/\(key)"
                )
            }

            for (key, value) in session.translationData {
                for (translationKey, translationValue) in value {
                    CoreDatabaseStore.addValue(
                        .init(
                            data: translationValue,
                            expiresAfter: .seconds(600)
                        ),
                        forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.translations.rawValue)/\(key)/\(translationKey)"
                    )
                }
            }

            for (key, value) in session.userData {
                CoreDatabaseStore.addValue(
                    .init(
                        data: value,
                        expiresAfter: .seconds(300)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.users.rawValue)/\(key)"
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
