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

    private(set) var willStartRecording = false

    private let outputFile = LockIsolated<AVAudioFile?>(nil)

    private var audioEngine: AVAudioEngine?

    // MARK: - Computed Properties

    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    // MARK: - Init

    override nonisolated init() {}

    // MARK: - Object Lifecycle

    @MainActor
    deinit {
        stopObservingInterruptions()
    }

    // MARK: - Recording

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

    func startRecording(
        bufferSink: (@Sendable (AVAudioPCMBuffer) -> Void)? = nil
    ) throws(Exception) {
        willStartRecording = true

        try audioService.activateAudioSession()
        let filePath = fileManager.documentsDirectoryURL.appending(path: FileNames.inputM4A)

        let audioEngine = AVAudioEngine()
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)

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

        startObservingInterruptions()
    }

    func stopRecording() throws(Exception) -> URL {
        willStartRecording = false
        stopObservingInterruptions()

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

    // MARK: - Interruptions

    private func startObservingInterruptions() {
        notificationCenter.addObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        ) { @Sendable notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                Task { @MainActor in
                    do throws(Exception) {
                        _ = try self.stopRecording()
                    } catch {
                        Logger.log(error)
                    }
                }

            default: ()
            }
        }
    }

    private func stopObservingInterruptions() {
        notificationCenter.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        )
    }
}
