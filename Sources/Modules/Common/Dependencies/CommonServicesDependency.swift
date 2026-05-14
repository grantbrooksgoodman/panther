//
//  CommonServicesDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum CommonServicesDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> CommonServices {
        @MainActorIsolated var attributeDetectionService = AttributeDetectionService.shared
        @MainActorIsolated var contactService = ContactService(contactPairArchive: .init())
        @MainActorIsolated var inviteService = InviteService()
        @MainActorIsolated var messageRecipientConsentService = MessageRecipientConsentService()
        @MainActorIsolated var messageRetranslationService = MessageRetranslationService()
        return .init(
            accountDeletion: .init(),
            aiEnhancedTranslation: .init(),
            analytics: .init(),
            attributeDetection: attributeDetectionService,
            audio: .init(
                playback: .init(),
                recording: .init(),
                textToSpeech: .init(),
                transcription: .init()
            ),
            breadcrumbsCapture: .shared,
            connectionStatus: .init(),
            contact: contactService,
            contentPicker: .init(
                camera: .init(),
                document: .init(),
                media: .init()
            ),
            documentExport: .init(),
            haptics: .init(),
            invite: inviteService,
            messageRecipientConsent: messageRecipientConsentService,
            messageRetranslation: messageRetranslationService,
            metadata: .shared,
            networkActivityIndicator: .init(),
            notification: .init(),
            penPals: .init(),
            permission: .init(),
            phoneNumber: .init(),
            propertyLists: .shared,
            pushToken: .init(),
            regionDetail: .init(),
            remoteCache: .init(),
            review: .init(),
            update: .shared
        )
    }
}

extension DependencyValues {
    var commonServices: CommonServices {
        get { self[CommonServicesDependency.self] }
        set { self[CommonServicesDependency.self] = newValue }
    }
}
