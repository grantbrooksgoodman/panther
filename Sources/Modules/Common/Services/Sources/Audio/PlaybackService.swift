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

/// Use ``PlaybackService`` to play audio files from disk.
///
/// The service plays one file at a time through a shared queue player; starting playback
/// replaces whatever is currently playing. Register one-shot effects to respond to playback
/// ending with ``onFinishedPlaying(_:)``, ``onFailedToFinishPlaying(_:)``, and
/// ``onStopPlaying(_:)``.
final class PlaybackService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avQueuePlayer) private var avQueuePlayer: AVQueuePlayer
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    /// The player item currently loaded for playback, or `nil` when playback has finished,
    /// failed, or been stopped.
    private(set) var currentPlayerItem: AVPlayerItem?

    private var failedToFinishPlayingEffect: (() -> Void)?
    private var finishedPlayingEffect: (() -> Void)?
    private var stopPlayingEffect: (() -> Void)?

    // MARK: - Computed Properties

    /// A Boolean value that indicates whether audio is currently queued for playback.
    var isPlaying: Bool {
        !avQueuePlayer.items().isEmpty
    }

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

    /// Plays the audio file at the given URL.
    ///
    /// This method activates the shared audio session and replaces any playback currently in
    /// progress.
    ///
    /// - Parameter url: The URL of the audio file to play.
    ///
    /// - Throws: An `Exception` if no file exists at the given URL, or if the audio session
    ///   cannot be activated.
    func playAudio(url: URL) throws(Exception) {
        guard fileManager.fileExists(atPath: url.path()) ||
            fileManager.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw Exception(
                "File does not exist.",
                userInfo: ["FilePath": url.path()],
                metadata: .init(sender: self)
            )
        }

        let playerItem = AVPlayerItem(url: url)
        currentPlayerItem = playerItem

        startObservingPlayerState()
        try audioService.activateAudioSession()

        avQueuePlayer.removeAllItems()
        avQueuePlayer.insert(playerItem, after: nil)
        avQueuePlayer.play()
    }

    /// Stops playback and clears the player queue.
    ///
    /// Stopping playback runs the effect registered with ``onStopPlaying(_:)``; it does not run
    /// the effects registered with ``onFinishedPlaying(_:)`` or ``onFailedToFinishPlaying(_:)``.
    func stopPlaying() {
        avQueuePlayer.removeAllItems()
        didStopPlaying()
    }

    // MARK: - Side Effects

    /// Registers an effect to run once, the next time playback fails to finish.
    ///
    /// The effect is cleared after it runs. Registering a new effect replaces any existing one.
    ///
    /// - Parameter effect: The effect to run.
    func onFailedToFinishPlaying(_ effect: @escaping () -> Void) {
        failedToFinishPlayingEffect = effect
    }

    /// Registers an effect to run once, the next time playback finishes.
    ///
    /// The effect is cleared after it runs. Registering a new effect replaces any existing one.
    ///
    /// - Parameter effect: The effect to run.
    func onFinishedPlaying(_ effect: @escaping () -> Void) {
        finishedPlayingEffect = effect
    }

    /// Registers an effect to run once, upon the next call to ``stopPlaying()``.
    ///
    /// The effect is cleared after it runs. Registering a new effect replaces any existing one.
    ///
    /// - Parameter effect: The effect to run.
    func onStopPlaying(_ effect: @escaping () -> Void) {
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
