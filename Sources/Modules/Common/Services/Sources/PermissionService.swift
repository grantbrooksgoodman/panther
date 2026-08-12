//
//  PermissionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFoundation
import Contacts
import Foundation
import Speech
import UIKit
import UserNotifications

/* Proprietary */
import AlertKit
import AppSubsystem

/// Use ``PermissionService`` to check, request, and prompt for system permissions.
///
/// The service covers the contacts, notifications, recording, and transcription permissions.
struct PermissionService {
    // MARK: - Types

    /// The authorization state of a system permission.
    enum PermissionStatus {
        /// The permission was denied or is restricted.
        case denied

        /// The permission was granted.
        case granted

        /// The permission has not yet been determined.
        case unknown
    }

    /// A system permission used by the app.
    enum PermissionType {
        /// Access to the user's contact list.
        case contacts

        /// Permission to display notifications, badges, and sounds.
        case notifications

        /// Access to the microphone.
        case recording

        /// Access to speech recognition.
        case transcription
    }

    // MARK: - Dependencies

    @Dependency(\.commonServices.audio) private var audioService: AudioService
    @Dependency(\.avAudioApplication) private var avAudioApplication: AVAudioApplication
    @Dependency(\.build) private var build: Build
    @Dependency(\.cnContactStore) private var contactStore: CNContactStore
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.userNotificationCenter) private var userNotificationCenter: UNUserNotificationCenter

    // MARK: - Computed Properties

    /// The current status of the contacts permission.
    var contactPermissionStatus: PermissionStatus {
        getContactPermissionStatus()
    }

    /// The current status of the notifications permission.
    var notificationPermissionStatus: PermissionStatus {
        get async {
            await getNotificationPermissionStatus()
        }
    }

    /// The current status of the recording permission.
    var recordPermissionStatus: PermissionStatus {
        getRecordPermissionStatus()
    }

    /// The current status of the transcription permission.
    var transcribePermissionStatus: PermissionStatus {
        getTranscribePermissionStatus()
    }

    // MARK: - Permissions Requesting

    /// Requests the given permission from the user.
    ///
    /// Requesting the recording permission also activates the shared audio session.
    ///
    /// - Parameter type: The permission to request.
    ///
    /// - Returns: The resulting permission status.
    ///
    /// - Throws: An `Exception` if the request fails.
    func requestPermission(for type: PermissionType) async throws(Exception) -> PermissionStatus {
        switch type {
        case .contacts:
            try await requestContactPermission()

        case .notifications:
            try await requestNotificationPermission()

        case .recording:
            try await requestRecordPermission()

        case .transcription:
            try await requestTranscribePermission()
        }
    }

    private func requestContactPermission() async throws(Exception) -> PermissionStatus {
        do {
            let requestAccessResult = try await contactStore.requestAccess(for: .contacts)
            return requestAccessResult ? .granted : .denied
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func requestNotificationPermission() async throws(Exception) -> PermissionStatus {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let requestAuthorizationResult = try await userNotificationCenter.requestAuthorization(
                options: authOptions
            )
            return requestAuthorizationResult ? .granted : .denied
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func requestRecordPermission() async throws(Exception) -> PermissionStatus {
        try audioService.activateAudioSession()
        return await AVAudioApplication.requestRecordPermission() ? .granted : .denied
    }

    private func requestTranscribePermission() async throws(Exception) -> PermissionStatus {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    switch status {
                    case .authorized:
                        continuation.resume(returning: .granted)

                    case .denied,
                         .restricted:
                        continuation.resume(returning: .denied)

                    case .notDetermined:
                        continuation.resume(returning: .unknown)

                    @unknown default:
                        continuation.resume(
                            throwing: Exception(
                                "Failed to get transcription permission.",
                                metadata: .init(sender: self)
                            )
                        )
                    }
                }
            }
        } catch {
            guard let exception = error as? Exception else {
                throw Exception(
                    error,
                    metadata: .init(sender: self)
                )
            }

            throw exception
        }
    }

    // MARK: - Call to Action Methods

    /// Presents an alert prompting the user to grant the given permission in Settings.
    ///
    /// - Parameter type: The permission the alert describes.
    ///
    /// - Returns: `true` if the user canceled the alert; otherwise, `false` if they chose to
    ///   open Settings.
    @discardableResult
    func presentCTA(
        for type: PermissionType
    ) async -> Bool {
        switch type {
        case .contacts: await presentContactCTA()
        case .notifications: await presentNotificationCTA()
        case .recording: await presentRecordingCTA()
        case .transcription: await presentTranscriptionCTA()
        }
    }

    private func presentContactCTA() async -> Bool {
        await presentCTA(
            with: "⌘\(build.finalName)⌘ has not been granted permission to access your contact list.\n\nYou can change this in Settings."
        )
    }

    private func presentNotificationCTA() async -> Bool {
        await presentCTA(
            with: "⌘\(build.finalName)⌘ has not been granted permission to send and receive notifications.\n\nYou can change this in Settings."
        )
    }

    private func presentRecordingCTA() async -> Bool {
        await presentCTA(
            with: "⌘\(build.finalName)⌘ needs access to your microphone to record audio messages.\n\nYou can grant this permission in Settings."
        )
    }

    private func presentTranscriptionCTA() async -> Bool {
        await presentCTA(
            with: "⌘\(build.finalName)⌘ needs speech recognition access to translate audio messages.\n\nYou can grant this permission in Settings."
        )
    }

    @MainActor
    private func presentCTA(
        with message: String
    ) async -> Bool {
        let cancelled = LockIsolated(true)

        @Localized(.settings) var settingsString: String
        let settingsURL = URL(string: UIApplication.openSettingsURLString)
        let resolvedSettingsString = settingsString.replacingOccurrences(of: "…", with: "...")

        var actions: [AKAction] = [.cancelAction]
        if let settingsURL,
           uiApplication.canOpenURL(settingsURL) {
            let settingsAction: AKAction = .init(resolvedSettingsString) {
                cancelled.wrappedValue = false
                Task { @MainActor in
                    uiApplication.open(settingsURL)
                }
            }

            actions.append(settingsAction)
        }

        await AKAlert(
            message: message,
            actions: actions
        ).present(translating: [.message])

        return cancelled.wrappedValue
    }

    // MARK: - Computed Property Getters

    private func getContactPermissionStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized,
             .limited:
            .granted
        case .denied,
             .restricted:
            .denied
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
    }

    private func getNotificationPermissionStatus() async -> PermissionStatus {
        await withCheckedContinuation { continuation in
            userNotificationCenter.getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized,
                     .ephemeral,
                     .provisional:
                    continuation.resume(returning: .granted)
                case .denied:
                    continuation.resume(returning: .denied)
                case .notDetermined:
                    continuation.resume(returning: .unknown)
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }

    private func getRecordPermissionStatus() -> PermissionStatus {
        var status: PermissionStatus {
            switch avAudioApplication.recordPermission {
            case .granted: .granted
            case .denied: .denied
            case .undetermined: .unknown
            @unknown default: .unknown
            }
        }

        return status
    }

    private func getTranscribePermissionStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            .granted
        case .denied,
             .restricted:
            .denied
        case .notDetermined:
            .unknown
        @unknown default:
            .unknown
        }
    }
}
