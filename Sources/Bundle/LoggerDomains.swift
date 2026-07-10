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

/// Use this extension to configure the app's logger domain
/// subscriptions.
///
/// Logger domains partition log output into named channels. Subscribe
/// to the domains you want to receive output from, and optionally
/// exclude specific domains from the on-disk session record.
///
/// To introduce a new domain for app-specific logging, define it as a
/// static property and add it to
/// ``SubscriptionDelegate/subscribedDomains``:
///
/// ```swift
/// extension LoggerDomain {
///     static let networking: LoggerDomain = .init("networking")
/// }
/// ```
extension LoggerDomain {
    // MARK: - Types

    /// The delegate that specifies which logger domains the app
    /// subscribes to at launch.
    struct SubscriptionDelegate: AppSubsystem.Delegates.LoggerDomainSubscriptionDelegate {
        /// The domains whose output is excluded from the on-disk
        /// session record.
        ///
        /// Messages logged to these domains still appear in the
        /// console, but are not written to the session record file.
        let domainsExcludedFromSessionRecord: [LoggerDomain] = [
            .caches,
            .concurrency,
            .observer,
        ]

        /// The domains the logger subscribes to at launch.
        ///
        /// Only messages logged to a subscribed domain produce output.
        /// Domains not listed here are silently ignored unless
        /// subscribed to at runtime.
        let subscribedDomains: [LoggerDomain] = [
            .alertKit,
            .analytics,
            .bugPrevention,
            .chatPageState,
            .contacts,
            .conversation,
            .conversationStore,
            .conversationSync,
            .dataIntegrity,
            .general,
            .Networking.hostedTranslation,
            .localization,
            .notifications,
            .penPals,
            .queue,
            .storageSession,
            .translation,
            .userSession,
            .userStore,
        ]
    }

    // MARK: - Properties

    static let analytics: LoggerDomain = .init("analytics")
    static let bugPrevention: LoggerDomain = .init("bugPrevention")
    static let chatPageState: LoggerDomain = .init("chatPageState")
    static let clientSession: LoggerDomain = .init("clientSession")
    static let contacts: LoggerDomain = .init("contacts")
    static let conversation: LoggerDomain = .init("conversation")
    static let conversationStore: LoggerDomain = .init("conversationStore")
    static let conversationSync: LoggerDomain = .init("conversationSync")
    static let dataIntegrity: LoggerDomain = .init("dataIntegrity")
    static let messageStore: LoggerDomain = .init("messageStore")
    static let notifications: LoggerDomain = .init("notifications")
    static let penPals: LoggerDomain = .init("penPals")
    static let queue: LoggerDomain = .init("queue")
    static let sessionStoreInvalidation: LoggerDomain = .init("sessionStoreInvalidation")
    static let storageSession: LoggerDomain = .init("storageSession")
    static let userSession: LoggerDomain = .init("userSession")
    static let userStore: LoggerDomain = .init("userStore")
}
