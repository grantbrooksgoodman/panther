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

/* 3rd-party */
import Redux

public struct InputBarConfigService {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.clientSession) private var clientSession: ClientSession

    // MARK: - Computed Properties

    public var canConfigureInputBarForRecording: Bool {
        guard let currentUser = clientSession.user.currentUser,
              let conversation = clientSession.conversation.currentConversation else { return false }

        guard currentUser.canSendAudioMessages else { return !(audioService.acknowledgedAudioMessagesUnsupported ?? false) }
        guard let users = conversation.users else { return !conversation.isMock /* TODO: Audit this. */ }
        return users.allSatisfy { currentUser.canSendAudioMessages(to: $0) /* TODO: Potential to be unlocked in removing this requirement. */ }
    }

    // MARK: - Public

    public func sendButtonImage(forRecording: Bool, isHighlighted: Bool) -> UIImage? {
        guard forRecording else {
            guard ThemeService.isDefaultThemeApplied else {
                return .init(named: isHighlighted ? Strings.sendButtonAlternateHighlightedImageName : Strings.sendButtonAlternateDefaultImageName)
            }

            return .init(named: isHighlighted ? Strings.sendButtonPrimaryHighlightedImageName : Strings.sendButtonPrimaryDefaultImageName)
        }

        return .init(named: isHighlighted ? Strings.recordButtonHighlightedImageName : Strings.recordButtonDefaultImageName)
    }
}
