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

enum AVAudioApplicationDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> AVAudioApplication {
        .shared
    }
}

extension DependencyValues {
    var avAudioApplication: AVAudioApplication {
        get { self[AVAudioApplicationDependency.self] }
        set { self[AVAudioApplicationDependency.self] = newValue }
    }
}
