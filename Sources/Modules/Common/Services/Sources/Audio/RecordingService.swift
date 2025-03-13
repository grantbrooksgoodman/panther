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

public final class RecordingService: NSObject {
    // MARK: - Type Aliases

    private typealias FileNames = AudioService.FileNames

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avAudioSession) private var avAudioSession: AVAudioSession
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    public private(set) var willStartRecording = false

    private var audioRecorder: AVAudioRecorder?

    // MARK: - Computed Properties

    public var isRecording: Bool { audioRecorder?.isRecording ?? false }

    // MARK: - Object Lifecycle

    deinit {
        stopObservingInterruptions()
    }

    // MARK: - Recording

    public func cancelRecording() -> Exception? {
        let stopRecordingResult = stopRecording()

        switch stopRecordingResult {
        case let .success(url):
            guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }

            do {
                try fileManager.removeItem(at: url)
            } catch {
                return .init(error, metadata: [self, #file, #function, #line])
            }

            return nil

        case let .failure(exception):
            return exception
        }
    }

    public func startRecording() -> Exception? {
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
            return .init(error, metadata: [self, #file, #function, #line])
        }

        startObservingInterruptions()
        return nil
    }

    public func stopRecording() -> Callback<URL, Exception> {
        willStartRecording = false

        stopObservingInterruptions()

        guard let audioRecorder else {
            return .failure(.init(
                "No audio recorder to stop.",
                metadata: [self, #file, #function, #line]
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
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        )
    }

    private func stopObservingInterruptions() {
        notificationCenter.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: avAudioSession
        )
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            switch stopRecording() {
            case let .failure(exception):
                Logger.log(exception)

            default: ()
            }

        default: ()
        }
    }
}

/* MARK: AVAudioRecorderDelegate Conformance */

extension RecordingService: AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else {
            switch stopRecording() {
            case let .failure(exception):
                Logger.log(exception)

            default: ()
            }

            return
        }
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        switch stopRecording() {
        case .success:
            Logger.log(.init(error, metadata: [self, #file, #function, #line]))

        case let .failure(exception):
            Logger.log(exception)
        }
    }
}
