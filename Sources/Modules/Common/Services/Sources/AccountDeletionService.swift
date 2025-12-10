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

final class AccountDeletionService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.uiApplication.presentedViews) private var presentedViews: [UIView]

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

        core.ui.addOverlay(
            alpha: 0.5,
            activityIndicator: nil,
            isModal: false
        )

        core.hud.showProgress(
            text: Localized(.deletingData).wrappedValue,
            isModal: true
        )

        // Add to deleted users.

        if let exception = await addToDeletedUsers(currentUserID) {
            exceptions.append(exception)
        }

        // Synchronize conversations.

        if let exception = await clientSession.user.currentUser?.setConversations() {
            exceptions.append(exception)
        }

        let conversations = clientSession.user.currentUser?.conversations ?? []
        let groupChats = conversations.filter { $0.participants.count > 2 }
        let oneToOneChats = conversations.filter { $0.participants.count == 2 }

        let totalUnits = Double(groupChats.count + oneToOneChats.count)

        // Remove user from existing group chats.

        for groupChat in groupChats {
            let removeFromConversationResult = await clientSession.activity.removeFromConversation(
                currentUserID,
                conversation: groupChat,
                removeFromUser: false
            )

            switch removeFromConversationResult {
            case .success: continue
            case let .failure(exception): exceptions.append(exception)
            }

            incrementProgress(forTotal: totalUnits)
        }

        // Delete 1:1 conversations.

        for oneToOneChat in oneToOneChats {
            if let exception = await clientSession.conversation.deleteConversation(
                oneToOneChat,
                forced: true
            ) {
                exceptions.append(exception)
            }

            incrementProgress(forTotal: totalUnits)
        }

        // Zero-out all open conversation references for the current user.

        do {
            _ = try (await clientSession.user.currentUser?.updateValue(
                [],
                forKey: .conversationIDs
            ))?.get()
        } catch {
            exceptions.append(.init(error, metadata: .init(sender: self)))
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

private extension Double {
    var roundedString: String {
        String(Darwin.round(self * 100))
            .components(separatedBy: ".")
            .first ?? "0"
    }
}
