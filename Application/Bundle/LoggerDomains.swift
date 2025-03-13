//
//  LoggerDomains.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension LoggerDomain {
    // MARK: - Types

    struct SubscriptionDelegate: AppSubsystem.Delegates.LoggerDomainSubscriptionDelegate {
        public let domainsExcludedFromSessionRecord: [LoggerDomain] = [
            .caches,
            .observer,
        ]

        public let subscribedDomains: [LoggerDomain] = [
            .alertKit,
            .analytics,
            .bugPrevention,
            .chatPageState,
            .contacts,
            .conversation,
            .dataIntegrity,
            .general,
            .hostedTranslation,
            .notifications,
            .queue,
            .translation,
            .user,
            .userSession,
        ]
    }

    // MARK: - Properties

    static let analytics: LoggerDomain = .init("analytics")
    static let bugPrevention: LoggerDomain = .init("bugPrevention")
    static let chatPageState: LoggerDomain = .init("chatPageState")
    static let contacts: LoggerDomain = .init("contacts")
    static let conversation: LoggerDomain = .init("conversation")
    static let dataIntegrity: LoggerDomain = .init("dataIntegrity")
    static let hostedTranslation: LoggerDomain = .init("hostedTranslation")
    static let notifications: LoggerDomain = .init("notifications")
    static let queue: LoggerDomain = .init("queue")
    static let user: LoggerDomain = .init("user")
    static let userSession: LoggerDomain = .init("userSession")
}
