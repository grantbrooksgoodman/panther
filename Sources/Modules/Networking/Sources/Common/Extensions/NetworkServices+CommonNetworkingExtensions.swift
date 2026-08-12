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
    private enum NetworkServiceStore {
        static let conversationService = ConversationService(staging: .shared)
        static let integrityService = IntegrityService()
        static let messageService = MessageService(
            audio: .init(),
            media: .init()
        )
        static let schemaMigrationService = SchemaMigrationService.shared
        static let userService = UserService(testing: .init())
    }

    /// The service that manages conversations.
    var conversationService: ConversationService {
        NetworkServiceStore.conversationService
    }

    /// The service that validates and repairs the hosted database.
    var integrityService: IntegrityService {
        NetworkServiceStore.integrityService
    }

    /// The service that manages messages.
    var messageService: MessageService {
        NetworkServiceStore.messageService
    }

    /// The service that migrates the database to the current schema.
    var schemaMigrationService: SchemaMigrationService {
        NetworkServiceStore.schemaMigrationService
    }

    /// The service that manages users.
    var userService: UserService {
        NetworkServiceStore.userService
    }
}
