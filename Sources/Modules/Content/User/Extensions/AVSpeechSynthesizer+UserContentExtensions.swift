//
//  AVSpeechSynthesizer+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/07/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation

/* Proprietary */
import AppSubsystem

extension AVSpeechSynthesizer {
    /// Stops speech synthesis if it is currently speaking.
    func stopSpeakingIfNeeded() {
        guard isSpeaking else { return }
        stopSpeaking(at: .immediate)
    }
}
