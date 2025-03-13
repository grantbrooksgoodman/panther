//
//  AVAudioApplicationDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation

/* Proprietary */
import AppSubsystem

public enum AVAudioApplicationDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AVAudioApplication {
        .shared
    }
}

public extension DependencyValues {
    var avAudioApplication: AVAudioApplication {
        get { self[AVAudioApplicationDependency.self] }
        set { self[AVAudioApplicationDependency.self] = newValue }
    }
}
