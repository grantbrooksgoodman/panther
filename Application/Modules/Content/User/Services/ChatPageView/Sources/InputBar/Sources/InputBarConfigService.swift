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

public struct InputBarConfigService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageViewService.InputBar

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession

    // MARK: - Computed Properties

    public var canConfigureInputBarForRecording: Bool {
        guard let currentUser = clientSession.user.currentUser,
              let conversation = clientSession.conversation.currentConversation else { return false }

        guard currentUser.canSendAudioMessages,
              let users = conversation.users else { return !(audioService.acknowledgedAudioMessagesUnsupported ?? false) }
        return users.allSatisfy { currentUser.canSendAudioMessages(to: $0) /* TODO: Potential to be unlocked in removing this requirement. */ }
    }

    // MARK: - Public

    public func attachMediaButtonImage(isHighlighted: Bool) -> UIImage? {
        guard ThemeService.isDarkModeActive else { return .init(resource: isHighlighted ? .plusLightHighlighted : .plusLight) }
        return .init(resource: isHighlighted ? .plusDarkHighlighted : .plusDark)
    }

    public func sendButtonImage(forRecording: Bool, isHighlighted: Bool) -> UIImage? {
        guard build.isOnline else { return .init(systemName: Strings.sendButtonOfflineImageSystemName) }
        guard forRecording else {
            guard !Application.isInPrevaricationMode,
                  ThemeService.isAppDefaultThemeApplied else { return isHighlighted ? .sendAlternateHighlighted : .sendAlternate }
            return isHighlighted ? .sendHighlighted : .send
        }
        return isHighlighted ? .recordHighlighted : .record
    }
}
