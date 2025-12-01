//
//  AudioService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation

/* Proprietary */
import AppSubsystem

struct AudioService {
    // MARK: - Types

    enum FileNames {
        static let inputM4A = "input.\(MediaFileExtension.audio(.m4a).rawValue)"
        static let outputCAF = "output.\(MediaFileExtension.audio(.caf).rawValue)"
        static let outputM4A = "output.\(MediaFileExtension.audio(.m4a).rawValue)"
    }

    // MARK: - Dependencies

    @Dependency(\.avAudioSession) private var avAudioSession: AVAudioSession

    // MARK: - Properties

    let playback: PlaybackService
    let recording: RecordingService
    let textToSpeech: TextToSpeechService
    let transcription: TranscriptionService

    @Persistent(.acknowledgedAudioMessagesUnsupported) var acknowledgedAudioMessagesUnsupported: Bool?

    // MARK: - Init

    init(
        playback: PlaybackService,
        recording: RecordingService,
        textToSpeech: TextToSpeechService,
        transcription: TranscriptionService
    ) {
        self.playback = playback
        self.recording = recording
        self.textToSpeech = textToSpeech
        self.transcription = transcription
    }

    // MARK: - Methods

    @discardableResult
    func activateAudioSession() -> Exception? {
        do {
            try avAudioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            try avAudioSession.setActive(true)
        } catch {
            return .init(error, metadata: .init(sender: self))
        }

        return nil
    }
}
