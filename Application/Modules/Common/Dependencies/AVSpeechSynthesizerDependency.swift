//
//  AVSpeechSynthesizerDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation

/* 3rd-party */
import Redux

public enum AVSpeechSynthesizerDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AVSpeechSynthesizer {
        .init()
    }
}

public extension DependencyValues {
    var avSpeechSynthesizer: AVSpeechSynthesizer {
        get { self[AVSpeechSynthesizerDependency.self] }
        set { self[AVSpeechSynthesizerDependency.self] = newValue }
    }
}
