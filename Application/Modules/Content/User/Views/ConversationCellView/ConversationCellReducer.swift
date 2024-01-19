//
//  ConversationCellReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 17/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* 3rd-party */
import Redux

public struct ConversationCellReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.commonServices.contact.contactPairArchive) private var contactPairArchive: ContactPairArchiveService
    @Dependency(\.clientSessionService.user) private var userSessionService: UserSessionService

    // MARK: - Actions

    public enum Action {
        case viewAppeared

        case userInfoBadgeTapped
    }

    // MARK: - Feedback

    public enum Feedback {}

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Type Aliases */

        public typealias Floats = AppConstants.CGFloats.ConversationCellView

        /* MARK: Properties */

        // Bool
        public var isPresentingUserInfoAlert = false
        public var isShowingUnreadIndicator = false

        // Color
        public var chevronImageForegroundColor: Color = .init(uiColor: .subtitleText.lighter(by: 60) ?? .subtitleText)
        public var subtitleLabelTextForegroundColor: Color = .init(
            uiColor: .subtitleText.lighter(
                by: Floats.subtitleLabelForegroundColorAdjustmentPercentage
            ) ?? .subtitleText
        )

        // String
        public var dateLabelText = ""
        public var subtitleLabelText = ""
        public var titleLabelText = ""

        // Other
        public var contactImage: UIImage?
        public var conversation: Conversation
        public var otherUser: User?

        /* MARK: Init */

        public init(_ conversation: Conversation) {
            self.conversation = conversation
        }
    }

    // MARK: - Init

    public init() { RuntimeStorage.store(#file, as: .presentedViewName) }

    // MARK: - Reduce

    public func reduce(into state: inout State, for event: Event) -> Effect<Feedback> {
        switch event {
        case .action(.viewAppeared):
            guard let users = state.conversation.users,
                  let lastUser = users.last else { return .none }

            // Set title label text
            if let contactPair = users
                .compactMap({ contactPairArchive.getValue(userNumberHash: $0.phoneNumber.nationalNumberString.digits.compressedHash) })
                .sorted(by: { $0.contact.fullName < $1.contact.fullName })
                .first {
                state.titleLabelText = contactPair.contact.fullName
                if let imageData = contactPair.contact.imageData {
                    state.contactImage = UIImage(data: imageData)
                }
            } else {
                state.titleLabelText = lastUser.phoneNumber.formattedString(useFailsafe: false)
            }

            // TODO: If >1 other user, set avatar image to number of users.
            if users.count > 1 {
                state.titleLabelText += " + \(users.count - 1)"
            } else if let otherUser = users.first {
                state.otherUser = otherUser
            }

            // Set date & subtitle label text
            if let lastMessage = state.conversation.messages.last {
                state.dateLabelText = lastMessage.sentDate.formattedShortString

                if lastMessage.audioComponent == nil {
                    let isLastMessageFromCurrentUser = lastMessage.fromAccountID == userSessionService.currentUser?.id.key
                    state.subtitleLabelText = isLastMessageFromCurrentUser ? lastMessage.translation.input.value() : lastMessage.translation.output
                } else {
                    state.subtitleLabelText = "🔊 AUDIO MESSAGE (LOCALIZE!)"
                }
            }

            // Set unread indicator status
            if let lastMessageFromOtherUsers = state.conversation.messages.filter({ $0.fromAccountID != userSessionService.currentUser?.id.key }).last {
                state.isShowingUnreadIndicator = lastMessageFromOtherUsers.readDate == nil
            }

        case .action(.userInfoBadgeTapped):
            Logger.log("User info badge tapped.", metadata: [self, #file, #function, #line])
        }

        return .none
    }
}
