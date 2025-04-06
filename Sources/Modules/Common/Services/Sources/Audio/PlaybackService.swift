//
//  PlaybackService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Foundation

/* Proprietary */
import AppSubsystem

public final class PlaybackService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avQueuePlayer) private var avQueuePlayer: AVQueuePlayer
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    public private(set) var currentPlayerItem: AVPlayerItem?

    private var failedToFinishPlayingEffect: (() -> Void)?
    private var finishedPlayingEffect: (() -> Void)?
    private var stopPlayingEffect: (() -> Void)?

    // MARK: - Computed Properties

    public var isPlaying: Bool { !avQueuePlayer.items().isEmpty }

    // MARK: - Object Lifecycle

    deinit {
        notificationCenter.removeObserver(
            self,
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: currentPlayerItem
        )

        notificationCenter.removeObserver(
            self,
            name: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: currentPlayerItem
        )
    }

    // MARK: - Playback

    @discardableResult
    public func playAudio(url: URL) -> Exception? {
        guard fileManager.fileExists(atPath: url.path()) || fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            return .init(
                "File does not exist.",
                extraParams: ["FilePath": url.path()],
                metadata: [self, #file, #function, #line]
            )
        }

        let playerItem = AVPlayerItem(url: url)
        currentPlayerItem = playerItem

        startObservingPlayerState()
        audioService.activateAudioSession()

        avQueuePlayer.removeAllItems()
        avQueuePlayer.insert(playerItem, after: nil)
        avQueuePlayer.play()

        return nil
    }

    public func stopPlaying() {
        avQueuePlayer.removeAllItems()
        didStopPlaying()
    }

    // MARK: - Side Effects

    /// Sets an effect to be run once, upon the next posting of `AVPlayerItemFailedToPlayToEndTime` notification.
    public func onFailedToFinishPlaying(_ effect: @escaping () -> Void) {
        failedToFinishPlayingEffect = effect
    }

    /// Sets an effect to be run once, upon the next posting of `AVPlayerItemDidPlayToEndTime` notification.
    public func onFinishedPlaying(_ effect: @escaping () -> Void) {
        finishedPlayingEffect = effect
    }

    /// Sets an effect to be run once, upon the next call to `stopPlaying()`.
    public func onStopPlaying(_ effect: @escaping () -> Void) {
        stopPlayingEffect = effect
    }

    // MARK: - Auxiliary

    private func didStopPlaying() {
        stopPlayingEffect?()
        stopPlayingEffect = nil
        currentPlayerItem = nil
    }

    private func startObservingPlayerState() {
        notificationCenter.addObserver(
            self,
            name: AVPlayerItem.didPlayToEndTimeNotification,
            object: currentPlayerItem,
            removeAfterFirstPost: true
        ) { _ in
            self.finishedPlayingEffect?()
            self.finishedPlayingEffect = nil
            self.currentPlayerItem = nil
        }

        notificationCenter.addObserver(
            self,
            name: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: currentPlayerItem,
            removeAfterFirstPost: true
        ) { _ in
            self.failedToFinishPlayingEffect?()
            self.failedToFinishPlayingEffect = nil
            self.currentPlayerItem = nil
        }
    }
}
