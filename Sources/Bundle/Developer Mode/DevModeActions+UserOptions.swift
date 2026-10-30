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
        // MARK: - Properties

        /// The destination that pushes the user options page. Its actions reflect the current
        /// networking environment.
        static let action: DevModeAction = {
            var actions = [
                markMessagesUnreadAction,
                resetDeviceIDAction,
                setCurrentUserIDAction,
            ]

            if Networking.config.environment != .production {
                actions.insert(createNewMessagesAction, at: 0)
            }

            return DevModeAction(
                title: "User Options",
                iconConfiguration: .init(
                    backgroundColor: .indigo,
                    overlay: .symbol(name: "person.fill")
                ),
                destination: actions
            )
        }()

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
                iconConfiguration: .init(
                    backgroundColor: .pink,
                    overlay: .symbol(name: "text.bubble.fill")
                ),
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
                iconConfiguration: .init(
                    backgroundColor: .yellow,
                    overlay: .symbol(name: "envelope.badge.fill")
                ),
                perform: markMessagesUnread
            )
        }()

        private static let resetDeviceIDAction: DevModeAction = {
            @Sendable
            func resetDeviceID() {
                Task { @MainActor in
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

                    guard await AKConfirmationAlert(
                        title: "Reset Device ID",
                        message: "The identifier for this device will be regenerated."
                    ).present(translating: []) else { return }

                    DeviceID.reset()

                    do throws(Exception) {
                        try await currentUser?.updateDeviceIDIfNeeded()
                        coreHUD.flash(
                            "Reset Device ID",
                            image: .success
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
                title: "Reset Device ID",
                iconConfiguration: .init(
                    backgroundColor: .gray,
                    overlay: .symbol(name: "iphone")
                ),
                perform: resetDeviceID
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
                iconConfiguration: .init(
                    backgroundColor: .blue,
                    overlay: .symbol(name: "person.crop.circle.fill")
                ),
                perform: setCurrentUserID
            )
        }()
    }
}
