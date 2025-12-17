//
//  AudioMessagePlaybackService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

final class AudioMessagePlaybackService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageViewService.AudioMessagePlayback
    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.AudioMessagePlayback
    private typealias Strings = AppConstants.Strings.ChatPageViewService.AudioMessagePlayback

    // MARK: - Dependencies

    @Dependency(\.avSpeechSynthesizer) private var avSpeechSynthesizer: AVSpeechSynthesizer
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.chatPageViewService.recordingUI) private var recordingUIService: RecordingUIService?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private(set) var playingCell: AudioMessageCell?
    private(set) var playingMessage: Message?

    private let viewController: ChatPageViewController

    private var cellsAwaitingDurationLabelSet = [URL: AudioMessageCell]()
    private var playbackTimer: Timer?

    // MARK: - Init

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        stopPlaybackTimer()
        // NIT: Best to remove observers, but selector-based observers should be removed by the system anyway.
    }

    // MARK: - Did Tap Play Button

    @objc
    func didTapPlayButton(_ sender: UITapGestureRecognizer) {
        guard let cell = sender.view?.traversedSuperviews.compactMap({ $0 as? AudioMessageCell }).first else {
            Logger.log(.init(
                "Failed to locate audio message cell in view hierarchy.",
                metadata: .init(sender: self)
            ))
            return
        }

        if let exception = didTapPlayButton(in: cell) {
            Logger.log(exception, with: .toast)
        }
    }

    private func didTapPlayButton(in cell: AudioMessageCell) -> Exception? {
        guard let message = message(for: cell) else { return nil }
        let fallbackAudioFile = message.isFromCurrentUser ? message.audioComponent?.original : message.audioComponent?.translated
        guard let audioFile = audioFile(for: message) ?? fallbackAudioFile,
              !services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }

        services.haptics.generateFeedback(.medium)

        func deselectCellAndStopPlaybackTimer(playNextMessage: Bool) {
            (playingCell ?? cell).durationLabel.text = audioFile.duration.durationString
            (playingCell ?? cell).playButton.isSelected = false
            (playingCell ?? cell).progressView.progress = 0

            playingCell = nil
            playingMessage = nil
            stopPlaybackTimer()

            guard playNextMessage,
                  let nextAudioCell = nextAudioMessageCell(after: cell) else { return }
            coreGCD.after(.milliseconds(Floats.playNextMessageDelayMilliseconds)) { _ = self.didTapPlayButton(in: nextAudioCell) }
        }

        guard !cell.playButton.isSelected else {
            stopPlayback()
            return nil
        }

        avSpeechSynthesizer.stopSpeaking(at: .immediate)

        resetVisibleCells()
        playingCell = cell
        playingMessage = message
        startPlaybackTimer()

        cell.playButton.isSelected = true
        cell.progressView.tintColor = message.isFromCurrentUser ? UIColor(Colors.cellCurrentUserProgressViewTint) : .accent

        services.audio.playback.onFailedToFinishPlaying { deselectCellAndStopPlaybackTimer(playNextMessage: false) }
        services.audio.playback.onFinishedPlaying { deselectCellAndStopPlaybackTimer(playNextMessage: true) }

        return services.audio.playback.playAudio(url: audioFile.url)
    }

    // MARK: - Set Playing Cell

    func setPlayingCell(_ playingCell: AudioMessageCell) {
        self.playingCell = playingCell
    }

    // MARK: - Stop Playback

    func stopPlayback() {
        Task { @MainActor in
            services.audio.playback.stopPlaying()
            resetVisibleCells()
            stopPlaybackTimer()
        }
    }

    // MARK: - Update Duration Label If Needed

    func updateDurationLabelIfNeeded(forMessage message: Message) {
        guard let audioFile = audioFile(for: message) else { return }
        notificationCenter.addObserver(
            self,
            name: .init(rawValue: AppConstants.Strings.AudioFile.setDurationNotificationName),
            object: audioFile,
            removeAfterFirstPost: true
        ) { notification in
            Task { @MainActor in
                let conversation = self.viewController.currentConversation
                let collectionView = self.viewController.messagesCollectionView

                guard let messageIndex = conversation?.messages?.firstIndex(where: { $0.id == message.id }),
                      let audioMessageCell = collectionView.cellForItem(at: .init(
                          item: 0,
                          section: messageIndex
                      )) as? AudioMessageCell,
                      let duration = notification.audioFileDuration,
                      let url = notification.audioFileURL,
                      audioFile.url == url,
                      duration > 0 else { return }

                audioMessageCell.durationLabel.text = duration.durationString
            }
        }
    }

    // MARK: - Auxiliary

    @objc
    private func animatePlaybackProgress() {
        guard let playingCell,
              let playerItem = services.audio.playback.currentPlayerItem else { return }

        let currentTimeSeconds = Float(playerItem.currentTime().seconds)
        playingCell.durationLabel.text = currentTimeSeconds.durationString

        let progress: Float = .init(.init(currentTimeSeconds) / playerItem.duration.seconds)
        guard !progress.isNaN else { return }
        playingCell.progressView.setProgress(progress, animated: true)
    }

    private func audioFile(for message: Message) -> AudioFile? {
        guard let localAudioFilePath = message.localAudioFilePath else { return nil }
        return .init(
            message.isFromCurrentUser ? localAudioFilePath.inputFilePathURL : localAudioFilePath.outputFilePathURL
        )
    }

    private func message(for cell: AudioMessageCell) -> Message? {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell) else { return nil }
        return viewController.currentConversation?.messages?.itemAt(indexPath.section)
    }

    func nextAudioMessageCell(after cell: AudioMessageCell) -> AudioMessageCell? {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell) else { return nil }
        let nextIndexPath: IndexPath = .init(row: indexPath.row, section: indexPath.section + 1)
        return viewController.messagesCollectionView.cellForItem(at: nextIndexPath) as? AudioMessageCell
    }

    private func resetVisibleCells() {
        playingCell = nil
        playingMessage = nil

        for cell in viewController.messagesCollectionView.visibleCells {
            guard let cell = cell as? AudioMessageCell,
                  cell.playButton.isSelected || cell.progressView.progress > 0 else { continue }

            func setDefaultDurationLabelText() {
                cell.durationLabel.text = Strings.cellDefaultDurationLabelText
            }

            cell.playButton.isSelected = false
            cell.progressView.progress = 0

            guard let message = message(for: cell) else {
                setDefaultDurationLabelText()
                continue
            }

            let fallbackAudioFile = message.isFromCurrentUser ? message.audioComponent?.original : message.audioComponent?.translated
            guard let audioFile = audioFile(for: message) ?? fallbackAudioFile else {
                setDefaultDurationLabelText()
                continue
            }

            guard fallbackAudioFile == nil else {
                cell.durationLabel.text = fallbackAudioFile?.duration.durationString ?? Strings.cellDefaultDurationLabelText
                return
            }

            notificationCenter.addObserver(
                self,
                name: .init(rawValue: AppConstants.Strings.AudioFile.setDurationNotificationName),
                object: audioFile,
                removeAfterFirstPost: true
            ) { notification in
                guard let duration = notification.audioFileDuration,
                      let url = notification.audioFileURL else { return }

                Task { @MainActor in
                    for (audioFileURL, cell) in self.cellsAwaitingDurationLabelSet where audioFileURL == url {
                        cell.durationLabel.text = duration.durationString
                        self.cellsAwaitingDurationLabelSet[audioFileURL] = nil
                    }
                }
            }

            cellsAwaitingDurationLabelSet[audioFile.url] = cell
        }
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = .scheduledTimer(
            timeInterval: Floats.playbackTimerTimeInterval,
            target: self,
            selector: #selector(animatePlaybackProgress),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

private extension Notification {
    var audioFileDuration: Float? {
        userInfo?[
            AppConstants.Strings.AudioFile.durationNotificationUserInfoKey
        ] as? Float
    }

    var audioFileURL: URL? {
        userInfo?[
            AppConstants.Strings.AudioFile.urlNotificationUserInfoKey
        ] as? URL
    }
}
