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

/* 3rd-party */
import CoreArchitecture

public enum AVAudioSessionDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AVAudioSession {
        .sharedInstance()
    }
}

public extension DependencyValues {
    var avAudioSession: AVAudioSession {
        get { self[AVAudioSessionDependency.self] }
        set { self[AVAudioSessionDependency.self] = newValue }
    }
}
