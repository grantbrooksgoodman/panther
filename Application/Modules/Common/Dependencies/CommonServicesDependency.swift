//
//  CommonServicesDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum CommonServicesDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> CommonServices {
        .init(
            analytics: .init(),
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
            propertyLists: .init(),
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
