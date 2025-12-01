//
//  AVQueuePlayerDependency.swift
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

enum AVQueuePlayerDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> AVQueuePlayer {
        .init()
    }
}

extension DependencyValues {
    var avQueuePlayer: AVQueuePlayer {
        get { self[AVQueuePlayerDependency.self] }
        set { self[AVQueuePlayerDependency.self] = newValue }
    }
}
