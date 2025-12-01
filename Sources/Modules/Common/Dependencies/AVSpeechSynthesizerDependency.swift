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

/* Proprietary */
import AppSubsystem

enum AVSpeechSynthesizerDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> AVSpeechSynthesizer {
        .init()
    }
}

extension DependencyValues {
    var avSpeechSynthesizer: AVSpeechSynthesizer {
        get { self[AVSpeechSynthesizerDependency.self] }
        set { self[AVSpeechSynthesizerDependency.self] = newValue }
    }
}
