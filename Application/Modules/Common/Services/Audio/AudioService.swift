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

/* 3rd-party */
import Redux

public struct AudioService {
    // MARK: - Types

    public enum FileNames {
        public static let inputM4A = "input.m4a"
        public static let outputCAF = "output.caf"
        public static let outputM4A = "output.m4a"
    }

    // MARK: - Dependencies

    @Dependency(\.avAudioSession) private var avAudioSession: AVAudioSession

    // MARK: - Properties

    public let playback: PlaybackService
    public let recording: RecordingService
    public let textToSpeech: TextToSpeechService
    public let transcription: TranscriptionService

    // MARK: - Init

    public init(
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
    public func activateAudioSession() -> Exception? {
        do {
            try avAudioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )

            try avAudioSession.setActive(true)
        } catch {
            return .init(error, metadata: [self, #file, #function, #line])
        }

        return nil
    }

    public func highestQualityVoice(_ languageCode: String) -> AVSpeechSynthesisVoice? {
        func satisfiesConstraints(_ voice: AVSpeechSynthesisVoice) -> Bool {
            guard voice.quality == .enhanced,
                  !voice.audioFileSettings.isEmpty else { return false }
            return true
        }

        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(languageCode.lowercased()) }
            .first(where: { satisfiesConstraints($0) }) ?? .init(language: languageCode)
    }
}
