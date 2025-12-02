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

struct ReactionDetailsPageReducer: Reducer {
    // MARK: - Dependencies

    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Actions

    enum Action {
        case viewAppeared
        case viewDisappeared

        case doneHeaderItemTapped
        case updateViewID
    }

    // MARK: - State

    struct State: Equatable {
        /* MARK: Properties */

        let navigationTitle = Localized(.reactionDetails).wrappedValue.removingOccurrences(of: ["…"])

        var viewID = UUID()

        /* MARK: Computed Properties */

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

            guard let currentUser = clientSession.user.currentUser,
                  let reactions = clientSession
                  .conversation
                  .currentConversation?
                  .messages?
                  .first(where: { $0.id == chatPageViewService.contextMenu?.interaction.selectedMessageID })?
                  .reactions else { return [] }

            let userMap = Dictionary(
                uniqueKeysWithValues: (UserCache.knownUsers + [currentUser]).uniquedByID
                    .map { ($0.id, $0.reactionDisplayName) }
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
    }

    // MARK: - Reduce

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
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

private extension Array where Element == User {
    var uniquedByID: [User] {
        var set = Set<String>()
        return filter { set.insert($0.id).inserted }
    }
}

private extension User {
    var reactionDisplayName: String {
        id == User.currentUserID ? Localized(.you).wrappedValue : displayName
    }
}
