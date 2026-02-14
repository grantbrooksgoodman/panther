//
//  DatabaseDelegate+CommonNetworkingExtensions.swift
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

extension DatabaseDelegate {
    func clearTemporaryCaches() {
        CoreDatabaseStore.filter { $0.value.expiryThreshold != .seconds(300) }
    }

    func populateTemporaryCaches() async -> Exception? {
        @Dependency(\.build.milestone) var buildMilestone: Build.Milestone
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

            for (key, value) in session.userData {
                CoreDatabaseStore.addValue(
                    .init(
                        data: value,
                        expiresAfter: .seconds(300)
                    ),
                    forKey: "\(Networking.config.environment.shortString)/\(NetworkPath.users.rawValue)/\(key)"
                )
            }

            if buildMilestone != .generalRelease {
                Toast.show(.init(
                    .capsule(style: .info),
                    message: "Established database snapshot.",
                    perpetuation: .ephemeral(.seconds(5))
                ))
            }

            Logger.log(
                "Established database snapshot.",
                domain: .Networking.database,
                sender: self
            )

        case let .failure(exception):
            return exception
        }

        return nil
    }
}
