//
//  DevModeActions+StagingModeOptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 28/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum StagingModeOptions {
        // MARK: - Types

        /// A perspective that Developer Mode can reload the app as.
        private enum Perspective {
            /// A staged identity, resolved to an account on selection.
            case staged(StagedUserIdentity)

            /// An existing account.
            case user(id: String)

            // MARK: - Properties

            /// The staged user identity associated with the perspective,
            /// if applicable.
            var identity: StagedUserIdentity? {
                switch self {
                case let .staged(identity): identity
                case .user: nil
                }
            }
        }

        // MARK: - Properties

        /// The destination that pushes the staging mode options page. Its actions reflect the
        /// app's current state.
        @MainActor
        static var action: DevModeAction {
            @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
            @Persistent(.isInStagingMode) var isInStagingMode: Bool?

            var actions = [toggleStagingModeAction]
            if currentUser != nil,
               isInStagingMode == true {
                actions.insert(
                    contentsOf: [
                        stageConversationsAction,
                        switchPerspectiveAction,
                    ],
                    at: 0
                )
            }

            return .init(
                title: "Staging Mode Options",
                iconConfiguration: .init(
                    backgroundColor: .purple,
                    overlay: .symbol(name: "theatermasks.fill")
                ),
                destination: actions
            )
        }

        private static let stageConversationsAction: DevModeAction = {
            @Sendable
            func stageConversations() { // swiftlint:disable:next identifier_name
                @Dependency(\.networking.conversationService.staging) var _conversationStagingService: ConversationStagingService
                let conversationStagingService = UncheckedSendable(_conversationStagingService)

                Task { @MainActor in
                    @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?

                    var message = "All conversations for the current user will be deleted and staged versions created for App Store mockup creation."
                    if let persona = StagedUserIdentity.all.first(where: {
                        $0.phoneNumber.compiledNumberString == currentUser?.phoneNumber.compiledNumberString
                    }) {
                        message += "\n\nThe current user holds \(persona.name)\u{2019}s phone number, "
                        message += "so they will stand in for that persona and some staged conversations will be with themselves."
                    }

                    guard await AKConfirmationAlert(
                        title: "Stage Conversations",
                        message: message
                    ).present(translating: []) else { return }

                    do throws(Exception) {
                        try await conversationStagingService
                            .wrappedValue
                            .stageConversations()
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Stage Conversations",
                iconConfiguration: .init(
                    backgroundColor: .mint,
                    overlay: .symbol(name: "square.stack.3d.up.fill")
                ),
                perform: stageConversations
            )
        }()

        /// The destination that pushes the perspectives available for screenshot capture. The
        /// current perspective carries a checkmark, and the main user appears only after a
        /// staging pass.
        @MainActor
        private static var switchPerspectiveAction: DevModeAction {
            @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
            @Persistent(.stagedMainUserID) var stagedMainUserID: String?
            @Persistent(.stagedTwinLanguageCode) var stagedTwinLanguageCode: String?

            func overlayConfig(
                isCurrentPerspective: Bool,
                regionCode: String,
                symbolName: String
            ) -> SquareIconView.Configuration.OverlayConfiguration {
                if let emojiFlag = regionCode.emojiFlag {
                    return .text(
                        string: emojiFlag,
                        font: .system(scale: .custom(120))
                    )
                }

                return .symbol(
                    name: isCurrentPerspective ? "checkmark" : symbolName
                )
            }

            func perspectiveAction(
                title: String,
                perspective: Perspective,
                isCurrentPerspective: Bool,
                backgroundColor: Color,
                symbolName: String
            ) -> DevModeAction {
                @Dependency(\.commonServices.regionDetail.deviceRegionCode) var deviceRegionCode: String
                return DevModeAction(
                    title: title,
                    iconConfiguration: .init(
                        backgroundColor: isCurrentPerspective ? .green : backgroundColor,
                        overlay: overlayConfig(
                            isCurrentPerspective: isCurrentPerspective,
                            regionCode: perspective.identity?.phoneNumber.regionCode ?? deviceRegionCode,
                            symbolName: symbolName
                        )
                    ),
                    perform: {
                        guard !isCurrentPerspective else { return }
                        switchPerspective(
                            to: title,
                            perspective: perspective
                        )
                    }
                )
            }

            var identities = StagedUserIdentity.all
            if let stagedTwinLanguageCode {
                identities.append(.twin(for: stagedTwinLanguageCode))
            }

            // Staged accounts are identified by phone number, so the
            // checkmark follows the number rather than the account ID.
            var actions = identities.map { identity in
                perspectiveAction(
                    title: "\(identity.name) (\(identity.languageCode.uppercased()))",
                    perspective: .staged(identity),
                    isCurrentPerspective: identity.phoneNumber.compiledNumberString == currentUser?.phoneNumber.compiledNumberString,
                    backgroundColor: .blue,
                    symbolName: "person.fill"
                )
            }

            if let stagedMainUserID {
                actions.insert(
                    perspectiveAction(
                        title: "Main User",
                        perspective: .user(id: stagedMainUserID),
                        isCurrentPerspective: stagedMainUserID == currentUser?.id,
                        backgroundColor: .indigo,
                        symbolName: "person.crop.circle.fill"
                    ),
                    at: 0
                )
            }

            return .init(
                title: "Switch Perspective",
                iconConfiguration: .init(
                    backgroundColor: .indigo,
                    overlay: .symbol(name: "person.2.fill")
                ),
                destination: actions
            )
        }

        private static var toggleStagingModeAction: DevModeAction {
            @Sendable
            func toggleStagingMode() {
                @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                @Persistent(.isInStagingMode) var isInStagingMode: Bool?
                isInStagingMode = isInStagingMode == true ? nil : true
                coreHUD.showSuccess(
                    text: "Staging Mode \(isInStagingMode == true ? "Enabled" : "Disabled")"
                )
            }

            @Persistent(.isInStagingMode) var isInStagingMode: Bool?
            return .init(
                title: "Staging Mode",
                iconConfiguration: .init(
                    backgroundColor: .purple,
                    overlay: .symbol(name: "wand.and.stars")
                ),
                interaction: .switch(isOn: isInStagingMode == true),
                perform: toggleStagingMode
            )
        }

        // MARK: - Methods

        @Sendable
        private static func switchPerspective(
            to title: String,
            perspective: Perspective
        ) {
            Task { @MainActor in
                await AKActionSheet(
                    title: "Switch Perspective",
                    message: "The app will reset and reload as the selected user.",
                    actions: [
                        AKAction("Switch to \(title)") {
                            Task { @MainActor in
                                @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
                                @Dependency(\.navigation) var navigation: Navigation
                                @Persistent(.currentUserID) var currentUserID: String?

                                // Resolve before resetting, while the session
                                // can still reach the database.
                                let userID: String
                                switch perspective {
                                case let .staged(identity):
                                    coreUI.addOverlay(
                                        alpha: 0.5,
                                        activityIndicator: .largeWhite
                                    )

                                    defer { coreUI.removeOverlay() }
                                    do throws(Exception) {
                                        userID = try await StagedUserService.shared.resolveUser(
                                            for: identity
                                        ).id
                                    } catch {
                                        Logger.log(
                                            error,
                                            with: .toast
                                        )
                                        return
                                    }

                                case let .user(id):
                                    userID = id
                                }

                                guard userID != currentUserID else { return }
                                Application.dismissSheets()

                                // A full reset tears down the session, caches, and
                                // on-disk archives of the current user before the
                                // splash page resolves the new one.
                                Application.reset()
                                currentUserID = userID

                                navigation.navigate(to: .userContent(.stack([])))
                                navigation.navigate(to: .root(.modal(.splash)))
                            }
                        },
                    ]
                ).present(translating: [])
            }
        }
    }
}
