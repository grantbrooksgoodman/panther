//
//  InputBarConfigService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 03/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// The service that supplies the input bar's configuration values and button images.
///
/// Use ``InputBarConfigService`` to determine whether the send button can act as a record button
/// for the current conversation, and to obtain the appropriate images for the send and
/// attach-media buttons in the current state.
struct InputBarConfigService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.build) private var build: Build
    @Dependency(\.dataUsageService) private var dataUsageService: DataUsageService
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether the send button can be configured as a record
    /// button for the current conversation.
    var canShowRecordButton: Bool {
        guard let currentUser = entitySession
            .user
            .currentUser else { return false }

        let users = entitySession
            .conversation
            .currentConversation?
            .users ?? []

        guard currentUser.canSendAudioMessages,
              !users.isEmpty else {
            return !(audioService.acknowledgedAudioMessagesUnsupported ?? false)
        }

        // TODO: Potential to be unlocked in removing this requirement.
        return users.allSatisfy {
            currentUser.canSendAudioMessages(to: $0)
        }
    }

    // MARK: - Internal

    /// Returns the attach-media button's image for the current interface style.
    ///
    /// - Parameter isHighlighted: A Boolean value that indicates whether to return the
    ///   highlighted image.
    ///
    /// - Returns: The attach-media button's image, or `nil` if it cannot be created.
    @MainActor
    func attachMediaButtonImage(
        isHighlighted: Bool
    ) -> UIImage? {
        if !Application.usesLegacyChatPageInterface {
            return .init(
                systemName: Strings.v26AttachMediaButtonImageSystemName,
                withConfiguration: UIImage.SymbolConfiguration(weight: .medium)
            )?.withRenderingMode(.alwaysTemplate)
        }

        guard ThemeService.isDarkModeActive else {
            return .init(
                resource: isHighlighted ? .plusLightHighlighted : .plusLight
            )
        }

        return .init(
            resource: isHighlighted ? .plusDarkHighlighted : .plusDark
        )
    }

    /// Returns the send button's image for the given configuration.
    ///
    /// The image reflects the record or send configuration, and shows a distinct glyph when the
    /// app is offline in a new conversation or the data usage limit has been reached.
    ///
    /// - Parameters:
    ///   - forRecording: A Boolean value that indicates whether to return the record button's
    ///     image rather than the send button's.
    ///   - isHighlighted: A Boolean value that indicates whether to return the highlighted image.
    ///
    /// - Returns: The send button's image, or `nil` if it cannot be created.
    @MainActor
    func sendButtonImage(
        forRecording: Bool,
        isHighlighted: Bool
    ) -> UIImage? {
        if !build.isOnline,
           forRecording,
           navigation.state.userContent.sheet == .newChat {
            // Offline glyph only applies to audio/media; text sends are
            // allowed offline via the outbox fail-fast → auto-retry path.
            .init(systemName: Strings.sendButtonOfflineImageSystemName)
        } else if dataUsageService.atOrAboveDataUsageLimit {
            .init(systemName: Strings.sendButtonStorageLimitReachedImageSystemName)
        } else if forRecording {
            isHighlighted ? .recordHighlighted : .record
        } else if !Application.isInPrevaricationMode,
                  ThemeService.isAppDefaultThemeApplied {
            isHighlighted ? .sendHighlighted : .send
        } else {
            isHighlighted ? .sendAlternateHighlighted : .sendAlternate
        }
    }
}
