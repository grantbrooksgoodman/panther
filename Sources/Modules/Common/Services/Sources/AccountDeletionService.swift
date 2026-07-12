//
//  AccountDeletionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 13/11/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

final class AccountDeletionService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    @LockIsolated private var completedUnits: Double = 0
    @LockIsolated private var completionPercent: Double = 0 {
        didSet { updateHUDLabel() }
    }

    // MARK: - Delete Account

    // swiftlint:disable:next function_body_length
    func deleteAccount() async throws(Exception) {
        var exceptions = [Exception]()

        guard let currentUserID = User.currentUserID else {
            throw Exception(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        try clientSession.user.stopObservingCurrentUserChanges()
        defer { core.hud.hide() }

        await MainActor.run {
            core.ui.addOverlay(
                alpha: 0.5,
                activityIndicator: nil,
                isModal: false
            )
        }

        core.hud.showProgress(
            text: Localized(.deletingData).wrappedValue,
            isModal: true
        )

        // Add to deleted users + synchronize conversations.

        await withTaskGroup(
            of: Exception?.self
        ) { taskGroup in
            taskGroup.addTask {
                do throws(Exception) {
                    try await self.addToDeletedUsers(currentUserID)
                    return nil
                } catch {
                    return error
                }
            }

            taskGroup.addTask {
                do throws(Exception) {
                    try await self.clientSession.user.resolveCurrentUser(
                        and: [.conversations]
                    )

                    return nil
                } catch {
                    return error
                }
            }

            for await exception in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }
            }
        }

        let conversations = clientSession.user.currentUser?.conversations ?? []
        let groupChats = conversations.filter { $0.participants.count > 2 }
        let oneToOneChats = conversations.filter { $0.participants.count == 2 }

        let totalUnits = Double(groupChats.count + oneToOneChats.count)

        // Remove from group chats, delete 1:1 chats, and zero-out conversation IDs.

        await withTaskGroup(
            of: (
                exception: Exception?,
                trackProgress: Bool
            ).self
        ) { taskGroup in
            for groupChat in groupChats {
                taskGroup.addTask {
                    do throws(Exception) {
                        try await self.clientSession.activity.removeFromConversation(
                            currentUserID,
                            conversation: groupChat,
                            removeFromUser: false
                        )
                        return (nil, true)
                    } catch {
                        return (error, true)
                    }
                }
            }

            for oneToOneChat in oneToOneChats {
                taskGroup.addTask {
                    do throws(Exception) {
                        try await self.clientSession.conversation.deleteConversation(
                            oneToOneChat,
                            forced: true
                        )
                        return (nil, true)
                    } catch {
                        return (error, true)
                    }
                }
            }

            taskGroup.addTask {
                do throws(Exception) {
                    _ = try await self.clientSession.user.currentUser?.update(
                        \.conversationIDs,
                        to: []
                    )
                    return (nil, false)
                } catch {
                    return (error, false)
                }
            }

            for await (exception, trackProgress) in taskGroup {
                if let exception {
                    exceptions.append(exception)
                }

                if trackProgress {
                    incrementProgress(forTotal: totalUnits)
                }
            }
        }

        // Validate database integrity.

        try? await Task.sleep(for: .seconds(1))

        do {
            try await networking.integrityService.repairDatabase()
        } catch {
            exceptions.append(error)
        }

        // Delete user reference locally and on server.

        // Required because `repairDatabase()` unconditionally restarts observation.
        try? clientSession.user.stopObservingCurrentUserChanges()
        completionPercent = 1

        @Persistent(.currentUserID) var persistedCurrentUserID: String?
        persistedCurrentUserID = nil
        try? clientSession.user.setCurrentUser(nil)

        do {
            try await networking.database.setValue(
                NSNull(),
                forKey: "\(NetworkPath.users.rawValue)/\(currentUserID)"
            )
        } catch {
            exceptions.append(error)
        }

        // If we encountered errors, validate database integrity again.

        if !exceptions.isEmpty {
            do {
                try await networking.integrityService.repairDatabase()
            } catch {
                exceptions.append(error)
            }

            // Required because `repairDatabase()` unconditionally restarts observation.
            try? clientSession.user.stopObservingCurrentUserChanges()
        }

        if let exception = exceptions.compiledException {
            throw exception
        }
    }

    // MARK: - Auxiliary

    private func addToDeletedUsers(_ userID: String) async throws(Exception) {
        do {
            var deletedUserIDs: [String] = try await networking.database.getValues(
                at: NetworkPath.deletedUsers.rawValue
            )

            deletedUserIDs.append(userID)
            deletedUserIDs = deletedUserIDs.filter { $0 != .bangQualifiedEmpty }.unique

            try await networking.database.setValue(
                deletedUserIDs,
                forKey: NetworkPath.deletedUsers.rawValue
            )
        } catch {
            guard error.isEqual(
                to: .Networking.Database.noValueExists
            ) else { throw error }

            try await networking.database.setValue(
                [userID],
                forKey: NetworkPath.deletedUsers.rawValue
            )
        }
    }

    private func incrementProgress(forTotal total: Double) {
        $completedUnits.withValue {
            $0 += 1
            completionPercent = $0 / max(total, 1)
        }
    }

    private func updateHUDLabel() {
        Task { @MainActor in
            @Dependency(\.uiApplication.presentedViews) var presentedViews: [UIView]
            let statusString = Localized(.deletingData).wrappedValue
            let progressLabel = presentedViews
                .compactMap { $0 as? UILabel }
                .first(where: {
                    $0.text?.contains(statusString) == true
                })

            let roundedValue = completionPercent.roundedString
            guard let integer = Int(roundedValue),
                  integer < 100 else { return progressLabel?.text = Localized(.finishingUp).wrappedValue }

            progressLabel?.text = "\(statusString) (\(roundedValue)%)"
            progressLabel?.adjustsFontSizeToFitWidth = true
        }
    }
}
