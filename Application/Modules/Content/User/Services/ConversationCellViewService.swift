//
//  ConversationCellViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import AlertKit
import Redux

public final class ConversationCellViewService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact.contactPairArchive) private var contactPairArchive: ContactPairArchiveService
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    public private(set) var badgeDecrementAmount = 0

    // MARK: - Methods

    /// `.viewAppeared`
    public func cellViewData(for conversation: Conversation) -> ConversationCellViewData? {
        guard let users = conversation.users,
              let lastUser = users.last else { return nil }

        var titleLabelText: String
        var subtitleLabelText = ""
        var dateLabelText = ""
        var contactImage: UIImage?
        var isShowingUnreadIndicator = false
        var otherUser: User?

        // Set title label text
        if let contactPair = users
            .compactMap({ contactPairArchive.getValue(userNumberHash: $0.phoneNumber.nationalNumberString.digits.encodedHash) })
            .sorted(by: { $0.contact.fullName < $1.contact.fullName })
            .first {
            titleLabelText = contactPair.contact.fullName
            if let imageData = contactPair.contact.imageData {
                contactImage = UIImage(data: imageData)
            }
        } else {
            titleLabelText = lastUser.phoneNumber.formattedString(useFailsafe: false)
        }

        // TODO: If >1 other user, set avatar image to number of users.
        if users.count > 1 {
            titleLabelText += " + \(users.count - 1)"
        } else if let firstUser = users.first {
            otherUser = firstUser
        }

        // Set date & subtitle label text
        if let lastMessage = conversation.messages?.last {
            dateLabelText = lastMessage.sentDate.formattedShortString

            if lastMessage.audioComponent == nil {
                let isLastMessageFromCurrentUser = lastMessage.isFromCurrentUser
                subtitleLabelText = isLastMessageFromCurrentUser ? lastMessage.translation.input.value() : lastMessage.translation.output
            } else {
                subtitleLabelText = "🔊 \(Localized(.audioMessage).wrappedValue)"
            }
        }

        // Set unread indicator status
        if let lastMessageFromOtherUsers = conversation.messages?.filter({ !$0.isFromCurrentUser }).last {
            isShowingUnreadIndicator = lastMessageFromOtherUsers.readDate == nil
        }

        return .init(
            titleLabelText: titleLabelText,
            subtitleLabelText: subtitleLabelText,
            dateLabelText: dateLabelText,
            contactImage: contactImage,
            isShowingUnreadIndicator: isShowingUnreadIndicator,
            otherUser: otherUser
        )
    }

    /// `.deleteConversationButtonTapped`
    /// - Returns: `true` if the user selected the cancel option.
    public func presentDeletionActionSheet(_ title: String) async -> Bool {
        let actionSheet: AKActionSheet = .init(
            title: title,
            message: "Are you sure you'd like to delete this conversation?\nThis operation cannot be undone.",
            actions: [.init(title: "Delete", style: .destructive)],
            shouldTranslate: [.actions(indices: nil), .message],
            networkDependent: true
        )

        let actionID = await actionSheet.present()
        return actionID == -1
    }

    /// `.chatPageViewAppeared`,
    /// `.updateCurrentUserBadgeNumberReturned(exception)`
    public func setBadgeDecrementAmount(_ badgeDecrementAmount: Int) {
        self.badgeDecrementAmount = badgeDecrementAmount
    }

    /// `.updateReadDateReturned(.success)`
    public func updateCurrentUserBadgeNumber() async -> Exception? {
        guard let currentUser = userSession.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            )
        }

        let decrementResult = (currentUser.badgeNumber - badgeDecrementAmount)
        let newBadgeNumber = decrementResult < 0 ? 0 : decrementResult

        guard newBadgeNumber != currentUser.badgeNumber else {
            return .init(
                "New badge number is equal to current value.",
                metadata: [self, #file, #function, #line]
            )
        }

        let updateValueResult = await currentUser.updateValue(newBadgeNumber, forKey: .badgeNumber)

        switch updateValueResult {
        case .success:
            if let exception = await notificationService.setBadgeNumber(newBadgeNumber) {
                return exception
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }
}
