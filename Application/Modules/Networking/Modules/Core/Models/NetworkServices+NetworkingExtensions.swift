//
//  NetworkServices+NetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

public extension NetworkServices {
    enum NetworkServiceStore {
        public static let conversationService = ConversationService(archive: .init())
        public static let integrityService = IntegrityService()
        public static let messageService = MessageService(
            audio: .init(),
            legacy: .init(),
            media: .init()
        )
        public static let translationService = HostedTranslationService(
            archiver: .init(),
            languageRecognition: .init(),
            legacy: .init()
        )
        public static let userService = UserService(legacy: .init())
    }

    var conversationService: ConversationService { NetworkServiceStore.conversationService }
    var integrityService: IntegrityService { NetworkServiceStore.integrityService }
    var messageService: MessageService { NetworkServiceStore.messageService }
    var translationService: HostedTranslationService { NetworkServiceStore.translationService }
    var userService: UserService { NetworkServiceStore.userService }
}
