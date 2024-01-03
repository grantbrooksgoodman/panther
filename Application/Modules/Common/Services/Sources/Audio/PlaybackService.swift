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

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avQueuePlayer) private var avQueuePlayer: AVQueuePlayer
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    public var isPlaying: Bool { avQueuePlayer.items().isEmpty }

    // MARK: - Playback

    @discardableResult
    public func playAudio(url: URL) -> Exception? {
        guard let decodedPath = url.path().removingPercentEncoding,
              fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: decodedPath) else {
            return .init(
                "File does not exist.",
                extraParams: ["FilePath": url.path()],
                metadata: [self, #file, #function, #line]
            )
        }

        audioService.activateAudioSession()

        avQueuePlayer.removeAllItems()
        avQueuePlayer.insert(.init(url: url), after: nil)
        avQueuePlayer.play()

        return nil
    }

    public func stopPlaying() {
        avQueuePlayer.removeAllItems()
    }
}
