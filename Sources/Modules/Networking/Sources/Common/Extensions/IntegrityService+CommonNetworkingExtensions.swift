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
    /// Validates and repairs the hosted database, re-running from the start whenever a repair is
    /// applied, until the data validates.
    ///
    /// On its first run, this method clears the temporary directory, captures a rollback
    /// snapshot, and migrates the database to the current schema. It then runs a sequence of
    /// validation and repair passes – pruning deleted users and invalidated caches, and repairing
    /// malformed, broken, orphaned, mismatched, and non-existent data. Whenever a pass makes a
    /// change, the method restarts the entire sequence so that later passes operate on the
    /// repaired data.
    ///
    /// - Parameters:
    ///   - exceptions: The exceptions accumulated across previous runs. Pass `nil` to begin a new
    ///     repair.
    ///   - methodsUsedForRepair: The names of the repair passes applied across previous runs. Pass
    ///     `nil` to begin a new repair.
    ///   - isFirstRun: A Boolean value that indicates whether this is the first run of the repair
    ///     sequence.
    ///   - onProgressUpdate: A closure called with the repair progress, from `0` to `1`, as each
    ///     pass completes.
    ///
    /// - Throws: An `Exception` if the app must be updated before the database can be repaired, or
    ///   if any repair pass fails.
    func repairDatabase(
        _ exceptions: [Exception]? = nil,
        _ methodsUsedForRepair: [String]? = nil,
        isFirstRun: Bool = true,
        onProgressUpdate: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws(Exception) {
        @Dependency(\.alertKitConfig) var alertKitConfig: AlertKit.Config
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.build) var build: Build
        @Dependency(\.commonServices.metadata) var metadataService: MetadataService
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.rollbackService) var rollbackService: RollbackService

        if isFirstRun {
            do {
                try coreUtilities.eraseTemporaryDirectory()
                try await rollbackService.captureSnapshot()
                try await networking.schemaMigrationService.migrateDatabase()
            } catch {
                Logger.log(error)
            }
        }

        guard let hostedAppStoreBuildNumber = metadataService.appStoreBuildNumber else {
            try await metadataService.resolveValues()
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        guard hostedAppStoreBuildNumber <= build.buildNumber else {
            throw Exception(
                "Build must be updated before attempting database repair.",
                metadata: .init(sender: self)
            )
        }

        CoreDatabaseStore.clearStore()
        networking.storage.clearStore()

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        var exceptions = exceptions ?? .init()
        var methodsUsedForRepair = methodsUsedForRepair ?? .init()

        // Keep in sync with the number of `reportProgressUpdate` calls below.
        let progressUpdateStepCount = 15
        var completedProgressUpdateSteps = 0
        func reportProgressUpdate() async {
            completedProgressUpdateSteps += 1
            await onProgressUpdate?(
                Double(completedProgressUpdateSteps) / Double(progressUpdateStepCount)
            )
        }

        // Resolve Integrity Service Session

        do {
            try await resolveSession()
        } catch {
            throw error
        }

        try validateRepairSafety()
        await reportProgressUpdate()

        // Prune Deleted Users & Invalidated Caches

        do { try await pruneDeletedUsers() } catch { exceptions.append(error) }
        await reportProgressUpdate()

        do { try await pruneInvalidatedCaches() } catch { exceptions.append(error) }
        await reportProgressUpdate()

        // Repair Malformed Data

        let repairMalformedMessagesResult = await repairMalformedMessages()
        if let exception = repairMalformedMessagesResult.exception { exceptions.append(exception) }
        if repairMalformedMessagesResult.tookAction {
            methodsUsedForRepair.append("repairMalformedMessages")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let repairMalformedConversationsResult = await repairMalformedConversations()
        if let exception = repairMalformedConversationsResult.exception { exceptions.append(exception) }
        if repairMalformedConversationsResult.tookAction {
            methodsUsedForRepair.append("repairMalformedConversations")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let repairMalformedUsersResult = await repairMalformedUsers()
        if let exception = repairMalformedUsersResult.exception { exceptions.append(exception) }
        if repairMalformedUsersResult.tookAction {
            methodsUsedForRepair.append("repairMalformedUsers")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        // Repair Broken Data

        let resolveBrokenConversationChainResult = await resolveBrokenConversationChain()
        if let exception = resolveBrokenConversationChainResult.exception { exceptions.append(exception) }
        if resolveBrokenConversationChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenConversationChain")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveBrokenMessageChainResult = await resolveBrokenMessageChain()
        if let exception = resolveBrokenMessageChainResult.exception { exceptions.append(exception) }
        if resolveBrokenMessageChainResult.tookAction {
            methodsUsedForRepair.append("resolveBrokenMessageChain")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveMismatchedParticipantsResult = await resolveMismatchedParticipants()
        if let exception = resolveMismatchedParticipantsResult.exception { exceptions.append(exception) }
        if resolveMismatchedParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveMismatchedParticipants")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveNoAudioComponentMessagesResult = await resolveNoAudioComponentMessages()
        if let exception = resolveNoAudioComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoAudioComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoAudioComponentMessages")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveNoMediaComponentMessagesResult = await resolveNoMediaComponentMessages()
        if let exception = resolveNoMediaComponentMessagesResult.exception { exceptions.append(exception) }
        if resolveNoMediaComponentMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveNoMediaComponentMessages")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveNonExistentParticipantsResult = await resolveNonExistentParticipants()
        if let exception = resolveNonExistentParticipantsResult.exception { exceptions.append(exception) }
        if resolveNonExistentParticipantsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentParticipants")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveNonExistentTranslationsResult = await resolveNonExistentTranslations()
        if let exception = resolveNonExistentTranslationsResult.exception { exceptions.append(exception) }
        if resolveNonExistentTranslationsResult.tookAction {
            methodsUsedForRepair.append("resolveNonExistentTranslations")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveOrphanedMediaResult = await resolveOrphanedMedia()
        if let exception = resolveOrphanedMediaResult.exception { exceptions.append(exception) }
        if resolveOrphanedMediaResult.tookAction {
            methodsUsedForRepair.append("resolveOrphanedMedia")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        let resolveOrphanedMessagesResult = await resolveOrphanedMessages()
        if let exception = resolveOrphanedMessagesResult.exception { exceptions.append(exception) }
        if resolveOrphanedMessagesResult.tookAction {
            methodsUsedForRepair.append("resolveOrphanedMessages")
            return try await repairDatabase(
                exceptions,
                methodsUsedForRepair,
                isFirstRun: false,
                onProgressUpdate: onProgressUpdate
            )
        }

        await reportProgressUpdate()

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
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
                Task { @MainActor in
                    Toast.show(.init(
                        .banner(style: .info),
                        message: logMessage
                    ))
                }
            }

            Task { @MainActor in
                if let reportDelegate = alertKitConfig.reportDelegate as? ErrorReportingService {
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
                }
            }
        } else {
            Logger.log(
                logMessage,
                domain: .dataIntegrity,
                sender: self
            )

            if build.milestone != .generalRelease {
                Task { @MainActor in
                    Toast.show(.init(
                        .banner(style: .info),
                        message: logMessage
                    ))
                }
            }
        }

        if let exception = exceptions.compiledException {
            throw exception
        }
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
