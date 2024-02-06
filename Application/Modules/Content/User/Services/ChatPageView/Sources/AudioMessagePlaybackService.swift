//
//  AudioMessagePlaybackService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 06/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

public final class AudioMessagePlaybackService {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.AudioMessagePlaybackService
    private typealias Strings = AppConstants.Strings.AudioMessagePlaybackService

    // MARK: - Dependencies

    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter
    @Dependency(\.chatPageViewService.recordingUI) private var recordingUIService: RecordingUIService?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var cellsAwaitingDurationLabelSet = [URL: AudioMessageCell]()
    private var playbackTimer: Timer?
    private var playingCell: AudioMessageCell?

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Object Lifecycle

    deinit {
        stopPlaybackTimer()
        // TODO: Best to remove observers, but selector-based observers should be removed by the system anyway.
    }

    // MARK: - Did Tap Play Button

    public func didTapPlayButton(in cell: AudioMessageCell) -> Exception? {
        guard let message = message(for: cell),
              let audioFile = audioFile(for: message),
              !services.audio.recording.isInOrWillTransitionToRecordingState else { return nil }

        services.haptics.generateFeedback(.medium)

        func deselectCellAndStopPlaybackTimer() {
            cell.durationLabel.text = audioFile.duration.durationString
            cell.playButton.isSelected = false
            cell.progressView.progress = 0

            playingCell = nil
            stopPlaybackTimer()
        }

        guard !cell.playButton.isSelected else {
            resetVisibleCells()
            services.audio.playback.stopPlaying()
            return nil
        }

        resetVisibleCells()
        playingCell = cell
        startPlaybackTimer()

        cell.playButton.isSelected = true
        cell.progressView.tintColor = message.isFromCurrentUser ? UIColor(Colors.cellCurrentUserProgressViewTint) : .accent

        services.audio.playback.onFailedToFinishPlaying { deselectCellAndStopPlaybackTimer() }
        services.audio.playback.onFinishedPlaying { deselectCellAndStopPlaybackTimer() }

        return services.audio.playback.playAudio(url: audioFile.url)
    }
    
    // MARK: - Stop Playback

    public func stopPlayback() {
        Task { @MainActor in
            services.audio.playback.stopPlaying()
            resetVisibleCells()
            stopPlaybackTimer()
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
        return .init(message.isFromCurrentUser ? localAudioFilePath.inputFilePathURL : localAudioFilePath.outputFilePathURL)
    }

    @objc
    private func didSetDuration(_ notification: Notification) {
        typealias Strings = AppConstants.Strings.AudioFile
        guard let userInfo = notification.userInfo,
              let duration = userInfo[Strings.durationNotificationUserInfoKey] as? Float,
              let url = userInfo[Strings.urlNotificationUserInfoKey] as? URL else { return }

        Task { @MainActor in
            for (audioFileURL, cell) in cellsAwaitingDurationLabelSet where audioFileURL == url {
                cell.durationLabel.text = duration.durationString
                cellsAwaitingDurationLabelSet[audioFileURL] = nil
            }
        }
    }

    private func message(for cell: AudioMessageCell) -> Message? {
        guard let indexPath = viewController.messagesCollectionView.indexPath(for: cell),
              let messages = viewController.currentConversation?.messages,
              indexPath.section < messages.count else { return nil }
        return messages[indexPath.section]
    }

    private func resetVisibleCells() {
        playingCell = nil

        for cell in viewController.messagesCollectionView.visibleCells {
            guard let cell = cell as? AudioMessageCell,
                  cell.playButton.isSelected || cell.progressView.progress > 0 else { continue }

            cell.playButton.isSelected = false
            cell.progressView.progress = 0

            guard let message = message(for: cell),
                  let audioFile = audioFile(for: message) else {
                cell.durationLabel.text = Strings.cellDefaultDurationLabelText
                continue
            }

            notificationCenter.addObserver(
                self,
                selector: #selector(didSetDuration(_:)),
                name: .init(rawValue: AppConstants.Strings.AudioFile.setDurationNotificationName),
                object: audioFile
            )

            cellsAwaitingDurationLabelSet[audioFile.url] = cell
        }
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        playbackTimer = .scheduledTimer(
            timeInterval: 0.1,
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
