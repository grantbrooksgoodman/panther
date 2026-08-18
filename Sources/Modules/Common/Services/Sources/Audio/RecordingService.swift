//
//  RecordingService.swift
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

/// Use ``RecordingService`` to record audio from the device microphone.
///
/// The service records M4A audio to a fixed file in the app's Documents directory; starting a
/// new recording overwrites the previous one. When an audio session interruption begins or the
/// audio engine's configuration changes, any in-progress recording stops and is finalized
/// automatically; when the system's media services are reset, any in-progress recording is
/// discarded.
@MainActor
final class RecordingService: NSObject {
    // MARK: - Type Aliases

    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avAudioSession) private var avAudioSession: AVAudioSession
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    /// A Boolean value that indicates whether a recording is about to begin or is in progress.
    ///
    /// This value becomes `true` as soon as ``startRecording(bufferSink:)`` is called and
    /// remains `true` until the recording stops.
    private(set) var willStartRecording = false

    private let outputFile = LockIsolated<AVAudioFile?>(nil)

    private var audioEngine: AVAudioEngine?
    private var isObservingSessionEvents = false

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether a recording is in progress.
    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    // MARK: - Init

    override nonisolated init() {}

    // MARK: - Recording

    /// Stops the current recording and deletes its output file.
    ///
    /// - Throws: An `Exception` if no recording is in progress, or if the output file cannot be
    ///   deleted.
    func cancelRecording() throws(Exception) {
        let url = try stopRecording()
        guard fileManager.fileExists(atPath: url.path()) ||
            fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    /// Starts recording audio from the device microphone.
    ///
    /// This method activates the shared audio session and writes M4A audio to a fixed file in
    /// the app's Documents directory, overwriting any previous recording. If a write fails
    /// mid-recording, the recording stops and the failure is logged.
    ///
    /// - Parameter bufferSink: A closure that receives each captured audio buffer as it is
    ///   written, suitable for feeding a ``LiveTranscriptionSession``. The default is `nil`.
    ///
    /// - Throws: An `Exception` if the audio session cannot be activated, if the microphone is
    ///   unavailable, or if recording fails to start.
    func startRecording(
        bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) throws(Exception) {
        willStartRecording = true

        try audioService.activateAudioSession()
        let filePath = fileManager.documentsDirectoryURL.appending(path: FileNames.inputM4A)

        let audioEngine = AVAudioEngine()
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)

        // A 0 Hz / 0-channel format means the microphone is
        // unavailable (permission revoked, another app holds it, or media
        // services just reset); installing a tap with it raises an
        // uncatchable Objective-C exception.
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0 else {
            throw Exception(
                "The microphone is unavailable.",
                metadata: .init(sender: self)
            )
        }

        do {
            outputFile.wrappedValue = try AVAudioFile(
                forWriting: filePath,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: inputFormat.sampleRate,
                    AVNumberOfChannelsKey: inputFormat.channelCount,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ],
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )

            audioEngine.inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: inputFormat
            ) { @Sendable [weak self, outputFile = outputFile] buffer, _ in
                do {
                    try outputFile.wrappedValue?.write(from: buffer)
                } catch {
                    guard let self else { return }
                    Task { @MainActor in
                        do throws(Exception) {
                            _ = try self.stopRecording()
                            Logger.log(.init(
                                error,
                                metadata: .init(sender: self)
                            ))
                        } catch {
                            Logger.log(error)
                        }
                    }

                    return
                }

                bufferSink?(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            self.audioEngine = audioEngine
        } catch let error as Exception {
            audioEngine.stop()
            outputFile.wrappedValue = nil
            throw error
        } catch {
            audioEngine.stop()
            outputFile.wrappedValue = nil
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        startObservingSessionEventsIfNeeded()
    }

    /// Stops the current recording.
    ///
    /// The output file is finalized before this method returns.
    ///
    /// - Returns: The URL of the finalized recording file.
    ///
    /// - Throws: An `Exception` if no recording is in progress.
    func stopRecording() throws(Exception) -> URL {
        willStartRecording = false

        guard let audioEngine,
              let fileURL = outputFile.wrappedValue?.url else {
            throw Exception(
                "No audio recorder to stop.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        self.audioEngine = nil

        // Releasing the file reference finalizes the M4A container; the URL must not escape before then.
        outputFile.wrappedValue = nil
        return fileURL
    }

    // MARK: - Session Events

    private func handleMediaServicesReset() {
        // The audio server crashed; every engine and player in
        // the process is invalid. Tear down without touching the
        // dead engine, discard playback, and force the session to reconfigure.
        willStartRecording = false

        if audioEngine?.isRunning == true {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
        }

        audioEngine = nil
        outputFile.wrappedValue = nil

        audioService.playback.stopPlaying()
        audioService.invalidateSessionConfiguration()
    }

    private func startObservingSessionEventsIfNeeded() {
        // Closure-based observers cannot be unregistered individually,
        // so register once for the service's lifetime and let each
        // handler check the current recording state.
        guard !isObservingSessionEvents else { return }
        isObservingSessionEvents = true

        notificationCenter.addObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        ) { @Sendable notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began else { return }

            Task { @MainActor in
                guard self.audioEngine != nil else { return }
                self.stopRecordingGracefully()
            }
        }

        notificationCenter.addObserver(
            self,
            name: .AVAudioEngineConfigurationChange
        ) { @Sendable notification in
            // The engine stopped and the tap's captured format is stale; finalize what was recorded.
            let changedEngineID = (notification.object as? AVAudioEngine).map(ObjectIdentifier.init)
            Task { @MainActor in
                guard let changedEngineID,
                      let audioEngine = self.audioEngine,
                      ObjectIdentifier(audioEngine) == changedEngineID else { return }
                self.stopRecordingGracefully()
            }
        }

        notificationCenter.addObserver(
            self,
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: avAudioSession
        ) { @Sendable _ in
            Task { @MainActor in self.handleMediaServicesReset() }
        }
    }

    private func stopRecordingGracefully() {
        do throws(Exception) {
            _ = try stopRecording()
        } catch {
            Logger.log(error)
        }
    }
}
