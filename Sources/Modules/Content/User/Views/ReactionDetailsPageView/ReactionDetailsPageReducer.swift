//
//  ReactionDetailsPageReducer.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/03/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import ComponentKit

public struct ReactionDetailsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    public enum Action {
        case viewAppeared
        case viewDisappeared

        case doneHeaderItemTapped
        case updateViewID
    }

    // MARK: - State

    public struct State: Equatable {
        /* MARK: Properties */

        public let navigationTitle = Localized(.reactionDetails).wrappedValue.removingOccurrences(of: ["..."])

        public var viewID = UUID()

        /* MARK: Computed Properties */

        public var listItems: [ListRowView.Configuration] {
            @Dependency(\.chatPageViewService) var chatPageViewService: ChatPageViewService
            @Dependency(\.clientSession) var clientSession: ClientSession

            func listRowIcon(for style: Reaction.Style) -> Image? {
                SquareIconView.image(.init(
                    backgroundColor: style.squareIconBackgroundColor,
                    overlay: .text(
                        string: style.emojiValue,
                        font: .system(scale: .custom(90))
                    )
                )).swiftUIImage
            }

            guard let currentUser = clientSession.user.currentUser,
                  let reactions = clientSession
                  .conversation
                  .currentConversation?
                  .messages?
                  .first(where: { $0.id == chatPageViewService.contextMenu?.interaction.selectedMessageID })?
                  .reactions else { return [] }

            let userMap = Dictionary(
                uniqueKeysWithValues: ((clientSession.conversation.currentConversation?.users ?? []) + [currentUser])
                    .map { ($0.id, $0.displayName) }
            )

            return Dictionary(grouping: reactions, by: \.style)
                .compactMap { style, reactions -> (Reaction.Style, ListRowView.Configuration)? in
                    let innerText: String = reactions
                        .compactMap { userMap[$0.userID] }
                        .alphabeticallySorted
                        .joined(separator: "\n")
                    guard !innerText.isEmpty else { return nil }
                    return (style, ListRowView.Configuration(
                        .button {},
                        innerText: innerText,
                        isEnabled: false,
                        imageView: { listRowIcon(for: style) }
                    ))
                }
                .sorted { $0.0.orderValue < $1.0.orderValue }
                .map(\.1)
        }

        /* MARK: Init */

        public init() {}
    }

    // MARK: - Reduce

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            uiApplication.resignFirstResponders()

        case .doneHeaderItemTapped:
            RootSheets.dismiss()

        case .updateViewID:
            state.viewID = UUID()

        case .viewDisappeared:
            if UIApplication.v26FeaturesEnabled,
               navigation.state.userContent.sheet != .newChat {
                Task { @MainActor in
                    NavigationBar.setAppearance(.chatPageView)
                }
            }

            guard !Application.isInPrevaricationMode,
                  ThemeService.isAppDefaultThemeApplied,
                  !ThemeService.isDarkModeActive,
                  navigation.state.userContent.sheet == .newChat else { return .none }

            StatusBar.overrideStyle(.darkContent)
        }

        return .none
    }
}

private extension User {
    var displayName: String {
        @Dependency(\.clientSession.conversation.currentConversation) var currentConversation: Conversation?
        @Dependency(\.commonServices) var services: CommonServices

        @Persistent(.currentUserID) var currentUserID: String?
        guard id != currentUserID else { return Localized(.you).wrappedValue }

        if let currentConversation,
           !currentConversation.userSharesPenPalsDataWithCurrentUser(self),
           !services.penPals.isKnownToCurrentUser(id) || currentConversation.participants.count == 2 {
            return penPalsName
        }

        guard let contactPair = services.contact.contactPairArchive.getValue(phoneNumber: phoneNumber) else { return phoneNumber.formattedString() }
        return contactPair.contact.fullName
    }
}
