//
//  AudioServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum AudioServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AudioService {
        .init(
            playback: .init(),
            recording: .init(),
            textToSpeech: .init(),
            transcription: .init()
        )
    }
}

public extension DependencyValues {
    var audioService: AudioService {
        get { self[AudioServiceDependency.self] }
        set { self[AudioServiceDependency.self] = newValue }
    }
}
