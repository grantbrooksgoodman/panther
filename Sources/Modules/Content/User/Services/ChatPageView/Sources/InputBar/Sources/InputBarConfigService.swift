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

struct InputBarConfigService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.entity) private var entitySession: EntitySession
    @Dependency(\.userStorageService) private var userStorageService: UserStorageService

    // MARK: - Computed Properties

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

    @MainActor
    func sendButtonImage(
        forRecording: Bool,
        isHighlighted: Bool
    ) -> UIImage? {
        if !build.isOnline {
            .init(systemName: Strings.sendButtonOfflineImageSystemName)
        } else if userStorageService.atOrAboveDataUsageLimit {
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
