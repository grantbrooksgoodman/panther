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
import Redux

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
            contact: .init(
                contactPairArchive: .init(),
                sync: .init()
            ),
            invite: .init(),
            metadata: .init(),
            networkActivityIndicator: .init(),
            notification: .init(),
            permission: .init(),
            phoneNumber: .init(),
            propertyLists: .init(),
            regionDetail: .init(),
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
