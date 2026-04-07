//
//  IntegrityService+CommonNetworkingExtensions.swift
//  Panther
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

extension IntegrityService {
    func repairDatabase(
        _ exceptions: [Exception]? = nil,
        _ methodsUsedForRepair: [String]? = nil,
        isFirstRun: Bool = true
    ) async -> Exception? {
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.build) var build: Build
        @Dependency(\.commonServices.metadata) var metadataService: MetadataService
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.alertKitConfig.reportDelegate) var reportDelegate: AlertKit.ReportDelegate?
        @Dependency(\.clientSession.user) var userSession: UserSessionService

        if isFirstRun,
           let exception = coreUtilities.eraseTemporaryDirectory() {
            Logger.log(exception)
        }

        guard let hostedAppStoreBuildNumber = metadataService.appStoreBuildNumber else {
            if let exception = await metadataService.resolveValues() {
                return exception
            }

            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        guard hostedAppStoreBuildNumber <= build.buildNumber else {
            return .init(
                "Build must be updated before attempting database repair.",
                metadata: .init(sender: self)
            )
        }

        userSession.stopObservingCurrentUserChanges()

        CoreDatabaseStore.clearStore()
        networking.storage.clearStore()

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        var exceptions = exceptions ?? .init()
        var methodsUsedForRepair = methodsUsedForRepair ?? .init()

        // Resolve Integrity Service Session

        if let exception = await resolveSession() {
            userSession.startObservingCurrentUserChanges()
            return exception
        }

        // Prune Deleted Users & Invalidated Caches

        async let pruneDeletedUsersException = pruneDeletedUsers()
        async let pruneInvalidatedCachesException = pruneInvalidatedCaches()

        if let exception = await pruneDeletedUsersException {
            exceptions.append(exception)
        }

        if let exception = await pruneInvalidatedCachesException {
            exceptions.append(exception)
        }

        // Repair Malformed Data

        let repairMalformedMessagesResult = await repairMalformedMessages()
        if let exception = repairMalformedMessagesResult.exception { exceptions.append(exception) }
        if repairMalformedMessagesResult.tookAction {
            methodsUsedForRepair.append("repairMalformedMessages")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let repairMalformedConversationsResult = await repairMalformedConversations()
        if let exception = repairMalformedConversationsResult.exception { exceptions.append(exception) }
        if repairMalformedConversationsResult.tookAction {
            methodsUsedForRepair.append("repairMalformedConversations")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let repairMalformedUsersResult = await repairMalformedUsers()
        if let exception = repairMalformedUsersResult.exception { exceptions.append(exception) }
        if repairMalformedUsersResult.tookAction {
            methodsUsedForRepair.append("repairMalformedUsers")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        // Repair Broken Data

        let resolveBrokenConversationChainResult = await resolveBrokenConversationChain()
        if let exception = resolveBrokenConversationChainResult.exception { exceptions.append(exception) }
        if resolveBrokenConversationChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenConversationChain")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveBrokenMessageChainResult = await resolveBrokenMessageChain()
        if let exception = resolveBrokenMessageChainResult.exception { exceptions.append(exception) }
        if resolveBrokenMessageChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenMessageChain")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveMismatchedParticipantsResult = await resolveMismatchedParticipants()
        if let exception = resolveMismatchedParticipantsResult.exception { exceptions.append(exception) }
        if resolveMismatchedParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveMismatchedParticipants")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveNoAudioComponentMessagesResult = await resolveNoAudioComponentMessages()
        if let exception = resolveNoAudioComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoAudioComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoAudioComponentMessages")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveNoMediaComponentMessagesResult = await resolveNoMediaComponentMessages()
        if let exception = resolveNoMediaComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoMediaComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoMediaComponentMessages")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveNonExistentParticipantsResult = await resolveNonExistentParticipants()
        if let exception = resolveNonExistentParticipantsResult.exception { exceptions.append(exception) }
        if resolveNonExistentParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentParticipants")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveNonExistentTranslationsResult = await resolveNonExistentTranslations()
        if let exception = resolveNonExistentTranslationsResult.exception { exceptions.append(exception) }
        if resolveNonExistentTranslationsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentTranslations")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveOrphanedMediaResult = await resolveOrphanedMedia()
        if let exception = resolveOrphanedMediaResult.exception { exceptions.append(exception) }
        if resolveOrphanedMediaResult.tookAction {
            methodsUsedForRepair.append("resolveOrphanedMedia")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        let resolveOrphanedMessagesResult = await resolveOrphanedMessages()
        if let exception = resolveOrphanedMessagesResult.exception { exceptions.append(exception) }
        if resolveOrphanedMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveOrphanedMessages")
            return await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false
            )
        }

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
            userSession.startObservingCurrentUserChanges()
        }

        var logMessage = "Hosted data integrity was validated."
        if !methodsUsedForRepair.isEmpty {
            logMessage = "Hosted data needed repair. The following methods were employed:\n\(methodsUsedForRepair)"

            Logger.log(
                logMessage,
                domain: .dataIntegrity,
                sender: self
            )

            if build.milestone != .generalRelease {
                Toast.show(.init(
                    .banner(style: .info),
                    message: logMessage
                ))
            }

            guard let reportDelegate = reportDelegate as? ErrorReportingService else { return exceptions.compiledException }
            reportDelegate.fileReport(
                Exception(
                    "Hosted data needed repair.",
                    userInfo: [
                        "Descriptor": "Hosted data needed repair.",
                        "MethodsUsedForRepair": methodsUsedForRepair,
                    ],
                    metadata: .init(sender: self)
                ), showsToastOnSuccess: false
            )
        } else {
            Logger.log(
                logMessage,
                domain: .dataIntegrity,
                sender: self
            )

            if build.milestone != .generalRelease {
                Toast.show(.init(
                    .banner(style: .info),
                    message: logMessage
                ))
            }
        }

        return exceptions.compiledException
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
