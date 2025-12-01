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
        .init(
            accountDeletion: .init(),
            analytics: .init(),
            attributeDetection: .shared,
            audio: .init(
                playback: .init(),
                recording: .init(),
                textToSpeech: .init(),
                transcription: .init()
            ),
            breadcrumbsCapture: .shared,
            connectionStatus: .init(),
            contact: .init(contactPairArchive: .init()),
            contentPicker: .init(
                camera: .init(),
                document: .init(),
                media: .init()
            ),
            documentExport: .init(),
            haptics: .init(
                heavyImpactFeedbackGenerator: .init(style: .heavy),
                lightImpactFeedbackGenerator: .init(style: .light),
                mediumImpactFeedbackGenerator: .init(style: .medium),
                rigidImpactFeedbackGenerator: .init(style: .rigid),
                selectionFeedbackGenerator: .init(),
                softImpactFeedbackGenerator: .init(style: .soft)
            ),
            invite: .init(),
            messageRecipientConsent: .init(),
            messageRetranslation: .init(),
            metadata: .init(),
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
