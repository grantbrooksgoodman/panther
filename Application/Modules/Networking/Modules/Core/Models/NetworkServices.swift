//
//  NetworkServices.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkServices {
    // MARK: - Properties

    public let conversation: ConversationService
    public let core: CoreNetworkServices
    public let integrity: IntegrityService
    public let message: MessageService
    public let translation: HostedTranslationService
    public let user: UserService

    // MARK: - Init

    public init(
        conversation: ConversationService,
        core: CoreNetworkServices,
        integrity: IntegrityService,
        message: MessageService,
        translation: HostedTranslationService,
        user: UserService
    ) {
        self.conversation = conversation
        self.core = core
        self.integrity = integrity
        self.message = message
        self.translation = translation
        self.user = user
    }
}
