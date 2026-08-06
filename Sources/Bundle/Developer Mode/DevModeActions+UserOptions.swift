//
//  DevModeActions+UserOptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/08/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum UserOptions {
        // MARK: - User Options Action

        static let userOptionsAction: DevModeAction = {
            @Sendable
            func userOptions() {
                Task {
                    var devModeActions = [
                        markMessagesUnreadAction,
                        setCurrentUserIDAction,
                    ]

                    if Networking.config.environment != .production {
                        devModeActions.insert(
                            createNewMessagesAction,
                            at: 0
                        )
                    }

                    var akActions = devModeActions.map {
                        AKAction(
                            $0.title,
                            style: $0.isDestructive ? .destructive : .default,
                            effect: $0.perform
                        )
                    }

                    akActions.append(
                        AKAction(
                            "Back",
                            style: .cancel,
                            effect: presentActionSheet
                        )
                    )

                    await AKActionSheet(
                        title: "User Options",
                        actions: akActions
                    ).present(translating: [])
                }
            }

            return DevModeAction(
                title: "User Options",
                perform: userOptions
            )
        }()

        // MARK: - Auxiliary

        static let createNewMessagesAction: DevModeAction = {
            @Sendable
            func createNewMessages() {
                Task { @MainActor in
                    @Dependency(\.networking.userService.testing) var userTestingService: UserTestingService

                    let messageCount = await AKTextInputAlert(
                        title: "Create Random Messages",
                        message: "Enter the amount of messages to be created.",
                        attributes: .init(keyboardType: .numberPad)
                    ).present(translating: [])

                    guard let messageCount,
                          let integer = Int(messageCount) else { return }

                    do throws(Exception) {
                        try await userTestingService.createRandomMessages(
                            count: integer
                        )
                    } catch {
                        Logger.log(
                            error,
                            with: .errorAlert
                        )

                        Application.reset(onCompletion: .navigateToSplash)
                    }
                }
            }

            return DevModeAction(
                title: "Create New Random Messages",
                perform: createNewMessages
            )
        }()

        private static let markMessagesUnreadAction: DevModeAction = {
            @Sendable
            func markMessagesUnread() {
                Task { @MainActor in
                    @Dependency(\.clientSession.entity.user) var userSession: UserSessionService
                    @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI

                    guard await AKConfirmationAlert(
                        title: "Mark Messages Unread",
                        message: "All messages will be marked as unread for the current user."
                    ).present(translating: []) else { return }

                    defer { coreUI.removeOverlay() }
                    coreUI.addOverlay(
                        alpha: 0.5,
                        activityIndicator: .largeWhite
                    )

                    do throws(Exception) {
                        try await userSession.resolveCurrentUser(
                            and: [
                                .conversations,
                                .messages,
                            ]
                        )

                        guard let conversations = userSession
                            .currentUser?
                            .conversations else { return }

                        userSession.stopObservingCurrentUserChanges()

                        _ = try await conversations
                            .compactMap(\.messages)
                            .flatMap(\.self)
                            .filter { $0.currentUserReadReceipt != nil }
                            .parallelMap { @Sendable in
                                let message = $0
                                return try await message.update(
                                    \.readReceipts,
                                    to: (message.readReceipts ?? [])?.filter {
                                        $0 != message.currentUserReadReceipt
                                    }
                                )
                            }

                        Application.reset(
                            preserveCurrentUserID: true,
                            onCompletion: .navigateToSplash
                        )
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Mark Messages Unread",
                perform: markMessagesUnread
            )
        }()

        private static let setCurrentUserIDAction: DevModeAction = {
            @Sendable
            func setCurrentUserID() {
                Task { @MainActor in
                    @Dependency(\.navigation) var navigation: Navigation
                    @Persistent(.currentUserID) var currentUserID: String?

                    let input = await AKTextInputAlert(
                        message: "Set Current User ID",
                        attributes: .init(
                            capitalizationType: .none,
                            correctionType: .no
                        ),
                        confirmButtonTitle: "Done"
                    ).present(translating: [])

                    guard let input else { return }
                    if input != currentUserID {
                        Application.reset()
                    }

                    currentUserID = input
                    navigation.navigate(to: .root(.modal(.splash)))
                }
            }

            return DevModeAction(
                title: "Set Current User ID",
                perform: setCurrentUserID
            )
        }()
    }
}
