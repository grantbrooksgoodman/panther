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

/* 3rd-party */
import CoreArchitecture

public enum AVQueuePlayerDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AVQueuePlayer {
        .init()
    }
}

public extension DependencyValues {
    var avQueuePlayer: AVQueuePlayer {
        get { self[AVQueuePlayerDependency.self] }
        set { self[AVQueuePlayerDependency.self] = newValue }
    }
}
