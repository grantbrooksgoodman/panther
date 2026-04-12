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

    private var completedUnits: Double = 0
    private var completionPercent: Double = 0 {
        didSet { updateHUDLabel() }
    }

    // MARK: - Delete Account

    func deleteAccount() async -> Exception? {
        var exceptions = [Exception]()

        guard let currentUserID = User.currentUserID else {
            return .init(
                "Current user ID has not been set.",
                metadata: .init(sender: self)
            )
        }

        clientSession.user.stopObservingCurrentUserChanges()
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

        await withTaskGroup(of: Exception?.self) { taskGroup in
            taskGroup.addTask { await self.addToDeletedUsers(currentUserID) }
            taskGroup.addTask { await self.clientSession.user.currentUser?.setConversations() ?? nil }

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

        await withTaskGroup(of: (exception: Exception?, trackProgress: Bool).self) { taskGroup in
            for groupChat in groupChats {
                taskGroup.addTask {
                    let removeFromConversationResult = await self.clientSession.activity.removeFromConversation(
                        currentUserID,
                        conversation: groupChat,
                        removeFromUser: false
                    )

                    switch removeFromConversationResult {
                    case .success: return (nil, true)
                    case let .failure(exception): return (exception, true)
                    }
                }
            }

            for oneToOneChat in oneToOneChats {
                taskGroup.addTask {
                    await (
                        self.clientSession.conversation.deleteConversation(
                            oneToOneChat,
                            forced: true
                        ),
                        true
                    )
                }
            }

            taskGroup.addTask {
                do {
                    _ = await try (self.clientSession.user.currentUser?.updateValue(
                        [],
                        forKey: .conversationIDs
                    ))?.get()
                    return (nil, false)
                } catch {
                    return (.init(error, metadata: .init(sender: self)), false)
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

        if let exception = await networking.integrityService.repairDatabase() {
            exceptions.append(exception)
        }

        // Delete user reference locally and on server.

        clientSession.user.stopObservingCurrentUserChanges()
        completionPercent = 1

        @Persistent(.currentUserID) var persistedCurrentUserID: String?
        persistedCurrentUserID = nil
        _ = clientSession.user.setCurrentUser(nil)

        if let exception = await networking.database.setValue(
            NSNull(),
            forKey: "\(NetworkPath.users.rawValue)/\(currentUserID)"
        ) {
            exceptions.append(exception)
        }

        // If we encountered errors, validate database integrity again.

        if !exceptions.isEmpty {
            if let exception = await networking.integrityService.repairDatabase() {
                exceptions.append(exception)
            }

            clientSession.user.stopObservingCurrentUserChanges()
        }

        return exceptions.compiledException
    }

    // MARK: - Auxiliary

    private func addToDeletedUsers(_ userID: String) async -> Exception? {
        let getValuesResult = await networking.database.getValues(
            at: NetworkPath.deletedUsers.rawValue
        )

        switch getValuesResult {
        case let .success(values):
            guard var array = values as? [String] else { return .Networking.typecastFailed("array", metadata: .init(sender: self)) }

            array.append(userID)
            array = array.filter { $0 != .bangQualifiedEmpty }.unique

            if let exception = await networking.database.setValue(
                array,
                forKey: NetworkPath.deletedUsers.rawValue
            ) {
                return exception
            }

        case let .failure(exception):
            guard exception.isEqual(to: .Networking.Database.noValueExists) else { return exception }

            if let exception = await networking.database.setValue(
                [userID],
                forKey: NetworkPath.deletedUsers.rawValue
            ) {
                return exception
            }
        }

        return nil
    }

    private func incrementProgress(forTotal total: Double) {
        completedUnits += 1
        completionPercent = completedUnits / max(total, 1)
    }

    private func updateHUDLabel() {
        Task { @MainActor in
            @Dependency(\.uiApplication.presentedViews) var presentedViews: [UIView]
            let statusString = Localized(.deletingData).wrappedValue
            let progressLabel = presentedViews
                .compactMap { $0 as? UILabel }
                .first(where: { $0.text?.contains(statusString) == true })

            let roundedValue = completionPercent.roundedString
            guard let integer = Int(roundedValue),
                  integer < 100 else { return progressLabel?.text = Localized(.finishingUp).wrappedValue }

            progressLabel?.text = "\(statusString) (\(roundedValue)%)"
            progressLabel?.adjustsFontSizeToFitWidth = true
        }
    }
}
