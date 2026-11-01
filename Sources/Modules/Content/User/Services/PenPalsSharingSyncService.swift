//
//  PenPalsSharingSyncService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// The service that keeps the current user's PenPals sharing data
/// current for the participants they know.
///
/// Use ``PenPalsSharingSyncService`` to share the current user's
/// PenPals data with known participants whenever a PenPals
/// conversation is upserted into the session store or the contact
/// pair archive is updated. Changes are handled after a short
/// delay; rapid successive changes coalesce into a single update,
/// and a change that arrives while an update is in progress
/// schedules one more.
///
/// - Note: Each update upserts the conversations it writes, which
///   notifies this service again. The follow-up update finds every
///   known participant already shared with and performs no write,
///   so updates do not loop.
@MainActor
final class PenPalsSharingSyncService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.penPals) private var penPalsService: PenPalsService
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore

    // MARK: - Properties

    fileprivate static let shared = PenPalsSharingSyncService()

    private var contactPairArchiveChangeTask: Task<Void, Never>?
    private var isUpdatePending = false
    private var sessionStoreChangeTask: Task<Void, Never>?
    @SharedEvent(\.sessionStoreDidChange) private var sessionStoreDidChange
    private var updateTask: Task<Void, Never>?
    @SharedEvent(\.updatedContactPairArchive) private var updatedContactPairArchive

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    /// Begins observing session store and contact pair archive
    /// changes, if not already observing.
    func startObserving() {
        if contactPairArchiveChangeTask == nil {
            contactPairArchiveChangeTask = Task { [weak self] in
                guard let archiveChanges = self?.updatedContactPairArchive.events else { return }
                for await _ in archiveChanges {
                    self?.scheduleUpdate()
                }
            }
        }

        if sessionStoreChangeTask == nil {
            sessionStoreChangeTask = Task { [weak self] in
                guard let sessionStoreChanges = self?.sessionStoreDidChange.events else { return }
                for await change in sessionStoreChanges {
                    self?.handleChange(change)
                }
            }
        }
    }
}

private extension PenPalsSharingSyncService {
    // MARK: - Types

    private enum TaskID: String {
        case sharingDataUpdate
    }

    // MARK: - Methods

    private func handleChange(_ change: SessionStoreChange) {
        guard case let .conversations(upsertedIDKeys, _) = change,
              upsertedIDKeys.contains(where: {
                  sessionStore.conversations[$0]?.metadata.isPenPalsConversation == true
              }) else { return }
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.sharingDataUpdate.rawValue)",
            delay: .seconds(1)
        ) { @MainActor [weak self] in
            self?.updateSharingData()
        }
    }

    private func updateSharingData() {
        guard updateTask == nil else {
            isUpdatePending = true
            return
        }

        updateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            Logger.log(
                "Updating PenPals sharing data for known users.",
                domain: .penPals,
                sender: self
            )

            do throws(Exception) {
                try await penPalsService.updateSharingDataForKnownUsers()
            } catch {
                Logger.log(
                    error,
                    domain: .penPals
                )
            }

            updateTask = nil
            guard isUpdatePending else { return }
            isUpdatePending = false
            updateSharingData()
        }
    }
}

/// The dependency key that resolves ``PenPalsSharingSyncService``.
enum PenPalsSharingSyncServiceDependency: DependencyKey {
    /// Returns the shared PenPals sharing sync service instance.
    static func resolve(_: DependencyValues) -> PenPalsSharingSyncService {
        // swiftformat:disable all
        @MainActorIsolated var penPalsSharingSyncService = PenPalsSharingSyncService.shared
        return penPalsSharingSyncService // swiftformat:enable all
    }
}

extension DependencyValues {
    /// The service that keeps the current user's PenPals sharing
    /// data current for the participants they know.
    var penPalsSharingSyncService: PenPalsSharingSyncService {
        get { self[PenPalsSharingSyncServiceDependency.self] }
        set { self[PenPalsSharingSyncServiceDependency.self] = newValue }
    }
}
