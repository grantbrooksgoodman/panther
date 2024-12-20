//
//  IntegrityService+CommonNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable cyclomatic_complexity function_body_length

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public extension IntegrityService {
    func repairDatabase(
        _ exceptions: [Exception]? = nil,
        _ methodsUsedForRepair: [String]? = nil
    ) async -> Exception? {
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.alertKitConfig.reportDelegate) var reportDelegate: AlertKit.ReportDelegate?
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        userSession.stopObservingCurrentUserChanges()
        CoreDatabaseCache.clear()
        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        var exceptions = exceptions ?? .init()
        var methodsUsedForRepair = methodsUsedForRepair ?? .init()

        // Resolve Integrity Service Session

        if let exception = await resolveSession() {
            userSession.startObservingCurrentUserChanges()
            return exception
        }

        // Prune Invalidated Caches

        if let exception = await pruneInvalidatedCaches() {
            exceptions.append(exception)
        }

        // Repair Malformed Data

        let repairMalformedMessagesResult = await repairMalformedMessages()
        if let exception = repairMalformedMessagesResult.exception { exceptions.append(exception) }
        if repairMalformedMessagesResult.tookAction {
            methodsUsedForRepair.append("repairMalformedMessages")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let repairMalformedConversationsResult = await repairMalformedConversations()
        if let exception = repairMalformedConversationsResult.exception { exceptions.append(exception) }
        if repairMalformedConversationsResult.tookAction {
            methodsUsedForRepair.append("repairMalformedConversations")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let repairMalformedUsersResult = await repairMalformedUsers()
        if let exception = repairMalformedUsersResult.exception { exceptions.append(exception) }
        if repairMalformedUsersResult.tookAction {
            methodsUsedForRepair.append("repairMalformedUsers")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        // Repair Broken Data

        let resolveBrokenConversationChainResult = await resolveBrokenConversationChain()
        if let exception = resolveBrokenConversationChainResult.exception { exceptions.append(exception) }
        if resolveBrokenConversationChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenConversationChain")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveBrokenMessageChainResult = await resolveBrokenMessageChain()
        if let exception = resolveBrokenMessageChainResult.exception { exceptions.append(exception) }
        if resolveBrokenMessageChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenMessageChain")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveMismatchedParticipantsResult = await resolveMismatchedParticipants()
        if let exception = resolveMismatchedParticipantsResult.exception { exceptions.append(exception) }
        if resolveMismatchedParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveMismatchedParticipants")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveNoAudioComponentMessagesResult = await resolveNoAudioComponentMessages()
        if let exception = resolveNoAudioComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoAudioComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoAudioComponentMessages")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveNoMediaComponentMessagesResult = await resolveNoMediaComponentMessages()
        if let exception = resolveNoMediaComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoMediaComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoMediaComponentMessages")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveNonExistentParticipantsResult = await resolveNonExistentParticipants()
        if let exception = resolveNonExistentParticipantsResult.exception { exceptions.append(exception) }
        if resolveNonExistentParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentParticipants")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveNonExistentTranslationsResult = await resolveNonExistentTranslations()
        if let exception = resolveNonExistentTranslationsResult.exception { exceptions.append(exception) }
        if resolveNonExistentTranslationsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentTranslations")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        let resolveOrphanedMessagesResult = await resolveOrphanedMessages()
        if let exception = resolveOrphanedMessagesResult.exception { exceptions.append(exception) }
        if resolveOrphanedMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveOrphanedMessages")
            return await repairDatabase(exceptions, methodsUsedForRepair)
        }

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
            userSession.startObservingCurrentUserChanges()
        }

        if !methodsUsedForRepair.isEmpty {
            Logger.log(
                "Hosted data needed repair. The following methods were employed:\n\(methodsUsedForRepair)",
                domain: .dataIntegrity,
                metadata: [self, #file, #function, #line]
            )

            guard let reportDelegate = reportDelegate as? ErrorReportingService else { return exceptions.compiledException }
            reportDelegate.fileReport(
                Exception(
                    "Hosted data needed repair.",
                    extraParams: ["MethodsUsedForRepair": methodsUsedForRepair],
                    metadata: [self, #file, #function, #line]
                ), showsToastOnSuccess: false
            )
        } else {
            Logger.log(
                "Hosted data integrity was validated.",
                domain: .dataIntegrity,
                metadata: [self, #file, #function, #line]
            )
        }

        return exceptions.compiledException
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
