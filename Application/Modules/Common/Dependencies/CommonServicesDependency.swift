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

public enum CommonServicesDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CommonServices {
        .init(
            analytics: .init(),
            attributeDetection: .shared,
            audio: .init(
                playback: .init(),
                recording: .init(),
                textToSpeech: .init(),
                transcription: .init()
            ),
            connectionStatus: .init(),
            contact: .init(
                contactPairArchive: .init(),
                sync: .init()
            ),
            contentPicker: .init(
                camera: .init(),
                document: .init(),
                media: .init()
            ),
            haptics: .init(
                heavyImpactFeedbackGenerator: .init(style: .heavy),
                lightImpactFeedbackGenerator: .init(style: .light),
                mediumImpactFeedbackGenerator: .init(style: .medium),
                rigidImpactFeedbackGenerator: .init(style: .rigid),
                selectionFeedbackGenerator: .init(),
                softImpactFeedbackGenerator: .init(style: .soft)
            ),
            invite: .init(),
            metadata: .init(),
            networkActivityIndicator: .init(),
            notification: .init(),
            permission: .init(),
            phoneNumber: .init(),
            propertyLists: .shared,
            pushToken: .init(),
            regionDetail: .init(),
            remoteCache: .init(),
            review: .init(),
            textMessage: .init(),
            update: .init()
        )
    }
}

public extension DependencyValues {
    var commonServices: CommonServices {
        get { self[CommonServicesDependency.self] }
        set { self[CommonServicesDependency.self] = newValue }
    }
}
