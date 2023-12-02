//
//  PlaybackService.swift
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

public struct PlaybackService {
    // MARK: - Dependencies

    @Dependency(\.audioService) private var audioService: AudioService
    @Dependency(\.avQueuePlayer) private var avQueuePlayer: AVQueuePlayer

    // MARK: - Properties

    public var isPlaying: Bool { avQueuePlayer.items().isEmpty }

    // MARK: - Playback

    public func playAudio(url: URL) {
        audioService.activateAudioSession()

        avQueuePlayer.removeAllItems()
        avQueuePlayer.insert(.init(url: url), after: nil)
        avQueuePlayer.play()
    }

    public func stopPlaying() {
        avQueuePlayer.removeAllItems()
    }
}
