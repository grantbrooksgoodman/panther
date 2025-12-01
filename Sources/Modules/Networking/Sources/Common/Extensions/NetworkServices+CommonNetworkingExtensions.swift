//
//  NetworkServices+CommonNetworkingExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension NetworkServices {
    enum NetworkServiceStore {
        static let conversationService = ConversationService(archive: .init())
        static let integrityService = IntegrityService()
        static let messageService = MessageService(
            audio: .init(),
            legacy: .init(),
            media: .init()
        )
        static let userService = UserService(
            legacy: .init(),
            testing: .init()
        )
    }

    var conversationService: ConversationService { NetworkServiceStore.conversationService }
    var integrityService: IntegrityService { NetworkServiceStore.integrityService }
    var messageService: MessageService { NetworkServiceStore.messageService }
    var userService: UserService { NetworkServiceStore.userService }
}
