//
//  IntegrityService+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable function_body_length

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension IntegrityService {
    // MARK: - Types

    private struct RepairPass {
        /* MARK: Properties */

        fileprivate let name: String
        fileprivate let run: () async -> (tookAction: Bool, exception: Exception?)

        /* MARK: Init */

        fileprivate init(
            _ name: String,
            run: @escaping () async -> (tookAction: Bool, exception: Exception?)
        ) {
            self.name = name
            self.run = run
        }
    }

    private struct SweepResult {
        /* MARK: Properties */

        fileprivate let completedProgressUpdateSteps: Int
        fileprivate let exceptions: [Exception]
        fileprivate let methodsUsedForRepair: [String]

        /* MARK: Computed Properties */

        fileprivate var tookAction: Bool {
            !methodsUsedForRepair.isEmpty
        }
    }

    // MARK: - Properties

    /// The number of progress steps a single sweep reports: safety validation, the two pruning
    /// passes, and each repair pass.
    private static let progressUpdateStepsPerSweep = 15

    /// The number of sweeps after which a repair that keeps changing data is abandoned.
    private static let maximumSweepCount = 5

    // MARK: - Repair Database

    /// Validates and repairs the hosted database, sweeping through every repair pass and then
    /// re-validating against fresh data until it validates.
    ///
    /// On its first sweep, this method clears the temporary directory, resolves a snapshot of the
    /// database, and migrates that snapshot to the current schema. It then runs a sequence of
    /// validation and repair passes – pruning deleted users and invalidated caches, and repairing
    /// malformed, broken, orphaned, mismatched, and non-existent data. Each pass applies the
    /// updates it commits to the snapshot, so later passes in the same sweep operate on the
    /// repaired data. Whenever a sweep makes a change, the method resolves a fresh snapshot and
    /// sweeps again to confirm the database validates.
    ///
    /// - Parameter onProgressUpdate: A closure called with the repair progress, from `0` to `1`,
    ///   as each pass completes. Progress does not restart when an additional sweep is needed.
    ///
    /// - Throws: An `Exception` if the app must be updated before the database can be repaired, if
    ///   the database still needs repair after the maximum number of sweeps, or if any repair pass
    ///   fails.
    func repairDatabase(
        onProgressUpdate: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws(Exception) {
        @Dependency(\.alertKitConfig) var alertKitConfig: AlertKit.Config
        @Dependency(\.coreKit.utils) var coreUtilities: CoreKit.Utilities
        @Dependency(\.build) var build: Build
        @Dependency(\.commonServices.metadata) var metadataService: MetadataService
        @Dependency(\.networking) var networking: NetworkServices
        @Dependency(\.rollbackService) var rollbackService: RollbackService

        // Refuse to repair unless the realtime connection is established.
        guard await networking.database.awaitRealtimeConnection(
            timeout: .seconds(15)
        ) else {
            throw Exception( // swiftlint:disable:next line_length
                "Aborting database repair: the realtime connection is not established. Repair must read authoritative server data and must never act on a cached snapshot.",
                metadata: .init(sender: self)
            )
        }

        // Revalidate first so the version gate is never evaluated
        // against a stale, persisted build number.
        try await metadataService.resolveValues()
        guard let hostedAppStoreBuildNumber = metadataService.appStoreBuildNumber else {
            throw Exception(
                "Failed to resolve hosted App Store build number.",
                metadata: .init(sender: self)
            )
        }

        guard hostedAppStoreBuildNumber <= build.buildNumber else {
            throw Exception(
                "Build must be updated before attempting database repair.",
                metadata: .init(sender: self)
            )
        }

        do {
            try coreUtilities.eraseTemporaryDirectory()
        } catch {
            Logger.log(error)
        }

        CoreDatabaseStore.clearStore()
        networking.storage.clearStore()

        networking.database.setGlobalCacheStrategy(.disregardCache)
        networking.storage.setGlobalCacheStrategy(.disregardCache)

        defer {
            networking.database.setGlobalCacheStrategy(nil)
            networking.storage.setGlobalCacheStrategy(nil)
        }

        var completedProgressUpdateSteps = 0
        var exceptions = [Exception]()
        var methodsUsedForRepair = [String]()
        var sweepCount = 0

        repeat {
            sweepCount += 1
            guard sweepCount <= Self.maximumSweepCount else {
                throw Exception(
                    "Database still needs repair after \(Self.maximumSweepCount) sweeps; aborting.",
                    userInfo: ["MethodsUsedForRepair": methodsUsedForRepair],
                    metadata: .init(sender: self)
                )
            }

            // Each sweep validates against authoritative data: the
            // first resolves and migrates the snapshot, and later
            // sweeps confirm the previous sweep's repairs.
            try await resolveSession()

            if sweepCount == 1 {
                do {
                    try await migrateSchema()
                } catch {
                    Logger.log(error)
                }
            }

            let sweepResult = try await sweep(
                sweepCount: sweepCount,
                startingProgressUpdateSteps: completedProgressUpdateSteps,
                onProgressUpdate: onProgressUpdate
            )

            completedProgressUpdateSteps = sweepResult.completedProgressUpdateSteps
            exceptions.append(contentsOf: sweepResult.exceptions)
            methodsUsedForRepair.append(contentsOf: sweepResult.methodsUsedForRepair)

            guard sweepResult.tookAction else { break }
        } while true

        let sendableRollbackService = UncheckedSendable(rollbackService)
        Task {
            do throws(Exception) {
                try await sendableRollbackService
                    .wrappedValue
                    .captureSnapshot()
            } catch {
                Logger.log(
                    error,
                    domain: .dataIntegrity
                )
            }
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

    // MARK: - Auxiliary

    /// Runs every validation and repair pass once over the current snapshot. Progress accumulates
    /// across sweeps so a confirming sweep continues from where the previous one ended.
    private func sweep(
        sweepCount: Int,
        startingProgressUpdateSteps: Int,
        onProgressUpdate: (@MainActor @Sendable (Double) -> Void)?
    ) async throws(Exception) -> SweepResult {
        var completedProgressUpdateSteps = startingProgressUpdateSteps
        var exceptions = [Exception]()
        var methodsUsedForRepair = [String]()

        func reportProgressUpdate() async {
            completedProgressUpdateSteps += 1
            await onProgressUpdate?(
                Double(completedProgressUpdateSteps) / Double(Self.progressUpdateStepsPerSweep * sweepCount)
            )
        }

        try validateRepairSafety()
        await reportProgressUpdate()

        // Prune Deleted Users & Invalidated Caches

        do { try await pruneDeletedUsers() } catch { exceptions.append(error) }
        await reportProgressUpdate()

        do { try await pruneInvalidatedCaches() } catch { exceptions.append(error) }
        await reportProgressUpdate()

        // Repair Malformed, Broken, Orphaned, Mismatched & Non-Existent Data

        let passes: [RepairPass] = [
            .init("repairMalformedMessages") { await repairMalformedMessages() },
            .init("repairMalformedConversations") { await repairMalformedConversations() },
            .init("repairMalformedUsers") { await repairMalformedUsers() },
            .init("resolveBrokenConversationChain") { await resolveBrokenConversationChain() },
            .init("resolveBrokenMessageChain") { await resolveBrokenMessageChain() },
            .init("resolveMismatchedParticipants") { await resolveMismatchedParticipants() },
            .init("resolveNoAudioComponentMessages") { await resolveNoAudioComponentMessages() },
            .init("resolveNoMediaComponentMessages") { await resolveNoMediaComponentMessages() },
            .init("resolveNonExistentParticipants") { await resolveNonExistentParticipants() },
            .init("resolveNonExistentTranslations") { await resolveNonExistentTranslations() },
            .init("resolveOrphanedMedia") { await resolveOrphanedMedia() },
            .init("resolveOrphanedMessages") { await resolveOrphanedMessages() },
        ]

        for pass in passes {
            let result = await pass.run()

            if let exception = result.exception {
                exceptions.append(exception)
            }

            if result.tookAction {
                methodsUsedForRepair.append(pass.name)
            }

            await reportProgressUpdate()
        }

        return .init(
            completedProgressUpdateSteps: completedProgressUpdateSteps,
            exceptions: exceptions,
            methodsUsedForRepair: methodsUsedForRepair
        )
    }
}

// swiftlint:enable function_body_length
