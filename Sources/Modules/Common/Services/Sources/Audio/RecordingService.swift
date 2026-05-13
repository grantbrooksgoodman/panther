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

    private var audioRecorder: AVAudioRecorder?

    // MARK: - Computed Properties

    var isRecording: Bool {
        audioRecorder?.isRecording ?? false
    }

    // MARK: - Init

    override nonisolated init() {}

    // MARK: - Object Lifecycle

    @MainActor
    deinit {
        stopObservingInterruptions()
    }

    // MARK: - Recording

    func cancelRecording() -> Exception? {
        let stopRecordingResult = stopRecording()

        switch stopRecordingResult {
        case let .success(url):
            guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }

            do {
                try fileManager.removeItem(at: url)
            } catch {
                return .init(error, metadata: .init(sender: self))
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }

    func startRecording() -> Exception? {
        willStartRecording = true

        audioService.activateAudioSession()

        let filePath = fileManager.documentsDirectoryURL.appending(path: FileNames.inputM4A)

        let audioSettings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: filePath, settings: audioSettings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
        } catch {
            audioRecorder?.stop()
            return .init(error, metadata: .init(sender: self))
        }

        startObservingInterruptions()
        return nil
    }

    func stopRecording() -> Callback<URL, Exception> {
        willStartRecording = false
        stopObservingInterruptions()

        guard let audioRecorder else {
            return .failure(.init(
                "No audio recorder to stop.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
        }

        audioRecorder.stop()
        let filePath = audioRecorder.url
        self.audioRecorder = nil
        return .success(filePath)
    }

    // MARK: - Interruptions

    private func startObservingInterruptions() {
        notificationCenter.addObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                Task { @MainActor in
                    switch self.stopRecording() {
                    case let .failure(exception): Logger.log(exception)
                    default: ()
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

/* MARK: AVAudioRecorderDelegate Conformance */

extension RecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor in
            guard flag else {
                switch stopRecording() {
                case let .failure(exception): Logger.log(exception)
                default: ()
                }
                return
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        Task { @MainActor in
            switch stopRecording() {
            case .success:
                Logger.log(.init(
                    error,
                    metadata: .init(sender: self)
                ))

            case let .failure(exception):
                Logger.log(exception)
            }
        }
    }
}
