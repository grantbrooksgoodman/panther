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

/// The reducer that drives the reaction details page.
///
/// This page lists the reactions on a message, grouped by reaction, showing which participants
/// reacted with each. The message is the one whose context menu the reaction details were opened
/// from.
///
/// The page's behavior contract:
///
/// - On appearance, the page dismisses the keyboard.
/// - The list shows one row per reaction style, each displaying the names of the participants who
///   reacted with it.
/// - Tapping done dismisses the page.
struct ReactionDetailsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    /// The actions the reaction details page can process.
    enum Action {
        /// An action that indicates the view appeared. Dismisses the keyboard.
        case viewAppeared

        /// An action that indicates the view disappeared. Restores the chat page's navigation bar
        /// appearance when applicable.
        case viewDisappeared

        /// An action that indicates the user tapped the done header item. Dismisses the page.
        case doneHeaderItemTapped

        /// An action that rebuilds the page's content from the latest values.
        case updateViewID
    }

    // MARK: - State

    /// The state of the reaction details page.
    struct State: Equatable {
        /* MARK: Properties */

        /// The identity of the page's content. Regenerated to rebuild it from the latest values.
        var viewID = UUID()

        /* MARK: Computed Properties */

        /// The list rows describing the message's reactions, one per reaction style, each showing
        /// the names of the participants who reacted with it.
        @MainActor
        var listItems: [ListRowView.Configuration] {
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

            guard let currentUser = clientSession.entity.user.currentUser,
                  let reactions = clientSession
                  .entity
                  .conversation
                  .currentConversation?
                  .messages?
                  .first(where: {
                      $0.id == chatPageViewService.contextMenu?.interaction.selectedMessageID
                  })?
                  .reactions else { return [] }

            let userMap = Dictionary(
                uniqueKeysWithValues: (
                    Array(clientSession.store.users.values) + [currentUser]
                ).uniquedByID.map { ($0.id, $0.reactionDisplayName) }
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

        /// The page's navigation title.
        var navigationTitle: String {
            let localizedString = Localized(
                .reactionDetails
            ).wrappedValue.removingOccurrences(of: ["…"])
            guard RuntimeStorage.languageCode == "en" else { return localizedString }
            return localizedString.capitalized
        }
    }

    // MARK: - Reduce

    /// Updates the page's state in response to the given action, returning any effect to run.
    ///
    /// - Parameters:
    ///   - state: The page's current state, mutated in place.
    ///   - action: The action to process.
    ///
    /// - Returns: An effect for the system to run, or `.none`.
    func reduce(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .viewAppeared:
            uiApplication.resignFirstResponders()

        case .doneHeaderItemTapped:
            RootSheets.dismiss()

        case .updateViewID:
            state.viewID = UUID()

        case .viewDisappeared:
            if UIApplication.isFullyV26Compatible,
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
    var reactionDisplayName: String {
        id == User.currentUserID ? Localized(.you).wrappedValue : displayName
    }
}
