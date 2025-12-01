//
//  AVAudioSessionDependency.swift
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

enum AVAudioSessionDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> AVAudioSession {
        .sharedInstance()
    }
}

extension DependencyValues {
    var avAudioSession: AVAudioSession {
        get { self[AVAudioSessionDependency.self] }
        set { self[AVAudioSessionDependency.self] = newValue }
    }
}
