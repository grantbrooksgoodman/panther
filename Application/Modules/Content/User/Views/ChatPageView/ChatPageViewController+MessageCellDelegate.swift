//
//  ChatPageViewController+MessageCellDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

extension ChatPageViewController: MessageCellDelegate {
    // MARK: - Constants Accessors

    private typealias Colors = AppConstants.Colors.ChatPageView
    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Did Select Date

    public func didSelectDate(_ date: Date) {
        guard let url = URL(string: "\(Strings.cellDelegateDateSelectionURLString)\(date.timeIntervalSinceReferenceDate)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select Phone Number

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "\(Strings.cellDelegatePhoneNumberSelectionURLString)\(phoneNumber.digits)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select URL

    public func didSelectURL(_ url: URL) {
        @Dependency(\.uiApplication) var uiApplication: UIApplication
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    // MARK: - Did Tap Play Button

    public func didTapPlayButton(in cell: AudioMessageCell) {
        @Dependency(\.commonServices.audio) var audioService: AudioService
        @Dependency(\.chatPageViewService.recordingUI) var recordingUIService: RecordingUIService?

        guard let indexPath = messagesCollectionView.indexPath(for: cell),
              let messages = currentConversation?.messages,
              indexPath.section < messages.count else { return }

        let message = messages[indexPath.section]
        guard let localAudioFilePath = message.localAudioFilePath else { return }

        let path = message.isFromCurrentUser ? localAudioFilePath.inputFilePathURL : localAudioFilePath.outputFilePathURL

        guard !cell.playButton.isSelected else {
            cell.playButton.isSelected = false
            cell.progressView.progress = 0

            if let audioFile = AudioFile(path) {
                cell.durationLabel.text = audioFile.duration.durationString
            }

            audioService.playback.stopPlaying()
            return
        }

        cell.playButton.isSelected = true
        cell.progressView.tintColor = message.isFromCurrentUser ? UIColor(Colors.cellDelegateAudioMessageCellCurrentUserProgressViewTint) : .accent

        guard !audioService.recording.isInOrWillTransitionToRecordingState else { return }
        if let exception = audioService.playback.playAudio(url: path) {
            Logger.log(exception, with: .toast())
        }
    }
}
