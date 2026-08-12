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

/// The umbrella service for audio functionality.
///
/// Use ``AudioService`` to access the app's audio sub-services – ``PlaybackService``,
/// ``RecordingService``, ``TextToSpeechService``, and ``TranscriptionService`` – and to manage
/// the shared audio session they depend on.
struct AudioService {
    // MARK: - Types

    /// A namespace for the directory names used for audio output.
    enum DirectoryNames {
        /// The prefix applied to directories containing text-to-speech synthesis output.
        static let textToSpeechOutputPrefix = "tts-"
    }

    /// A namespace for the file names used for audio input and output.
    enum FileNames {
        /// The name of the file to which audio recordings are written.
        static let inputM4A = "input.\(MediaFileExtension.audio(.m4a).rawValue)"

        /// The suffix of the file name to which text-to-speech synthesis output is written.
        static let outputM4A = "output.\(MediaFileExtension.audio(.m4a).rawValue)"
    }

    // MARK: - Dependencies

    @Dependency(\.avAudioSession) private var avAudioSession: AVAudioSession

    // MARK: - Properties

    /// The service that plays audio files from disk.
    let playback: PlaybackService

    /// The service that records audio from the device microphone.
    let recording: RecordingService

    /// The service that synthesizes speech from text.
    let textToSpeech: TextToSpeechService

    /// The service that transcribes recorded audio to text.
    let transcription: TranscriptionService

    /// A persisted flag that indicates whether the user has acknowledged the alert explaining
    /// that audio messages are unsupported.
    @Persistent(.acknowledgedAudioMessagesUnsupported) var acknowledgedAudioMessagesUnsupported: Bool?

    // MARK: - Init

    /// Creates an audio service with the given sub-services.
    ///
    /// - Parameters:
    ///   - playback: The service that plays audio files from disk.
    ///   - recording: The service that records audio from the device microphone.
    ///   - textToSpeech: The service that synthesizes speech from text.
    ///   - transcription: The service that transcribes recorded audio to text.
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

    /// Configures and activates the shared audio session for simultaneous playback and
    /// recording.
    ///
    /// The session is configured to default to the built-in speaker and to allow Bluetooth
    /// output. ``PlaybackService`` and ``RecordingService`` call this method automatically
    /// before starting playback or recording.
    ///
    /// - Throws: An `Exception` if the session cannot be configured or activated.
    func activateAudioSession() throws(Exception) {
        do {
            try avAudioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [
                    .allowBluetoothA2DP,
                    .allowBluetoothHFP,
                    .defaultToSpeaker,
                ]
            )

            try avAudioSession.setActive(true)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }
}
