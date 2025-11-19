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

public struct PermissionService {
    // MARK: - Types

    public enum PermissionStatus {
        case denied
        case granted
        case unknown
    }

    public enum PermissionType {
        case contacts
        case notifications
        case recording
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

    public var contactPermissionStatus: PermissionStatus { getContactPermissionStatus() }
    public var notificationPermissionStatus: PermissionStatus {
        get async {
            await getNotificationPermissionStatus()
        }
    }

    public var recordPermissionStatus: PermissionStatus { getRecordPermissionStatus() }
    public var transcribePermissionStatus: PermissionStatus { getTranscribePermissionStatus() }

    // MARK: - Permissions Requesting

    public func requestPermission(for type: PermissionType) async -> Callback<PermissionStatus, Exception> {
        switch type {
        case .contacts:
            return await requestContactPermission()

        case .notifications:
            return await requestNotificationPermission()

        case .recording:
            return await requestRecordPermission()

        case .transcription:
            return await requestTranscribePermission()
        }
    }

    private func requestContactPermission() async -> Callback<PermissionStatus, Exception> {
        do {
            let requestAccessResult = try await contactStore.requestAccess(for: .contacts)
            return .success(requestAccessResult ? .granted : .denied)
        } catch {
            return .failure(.init(error, metadata: .init(sender: self)))
        }
    }

    private func requestNotificationPermission() async -> Callback<PermissionStatus, Exception> {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        do {
            let requestAuthorizationResult = try await userNotificationCenter.requestAuthorization(options: authOptions)
            return .success(requestAuthorizationResult ? .granted : .denied)
        } catch {
            return .failure(.init(error, metadata: .init(sender: self)))
        }
    }

    private func requestRecordPermission() async -> Callback<PermissionStatus, Exception> {
        if let exception = audioService.activateAudioSession() {
            return .failure(exception)
        }

        return .success((await AVAudioApplication.requestRecordPermission()) ? .granted : .denied)
    }

    private func requestTranscribePermission() async -> Callback<PermissionStatus, Exception> {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .success(.granted))

                case .denied,
                     .restricted:
                    continuation.resume(returning: .success(.denied))

                case .notDetermined:
                    continuation.resume(returning: .success(.unknown))

                @unknown default:
                    continuation.resume(returning: .failure(.init("Failed to get transcription permission.", metadata: .init(sender: self))))
                }
            }
        }
    }

    // MARK: - Call to Action Methods

    /// - Returns: A `Bool` describing whether or not the user cancelled the operation.
    @discardableResult
    public func presentCTA(for type: PermissionType) async -> Bool {
        switch type {
        case .contacts:
            return await presentContactCTA()

        case .notifications:
            return await presentNotificationCTA()

        case .recording:
            return await presentRecordingCTA()

        case .transcription:
            return await presentTranscriptionCTA()
        }
    }

    private func presentContactCTA() async -> Bool {
        await presentCTA(with: "⌘\(build.finalName)⌘ has not been granted permission to access your contact list.\n\nYou can change this in Settings.")
    }

    private func presentNotificationCTA() async -> Bool {
        await presentCTA(with: "⌘\(build.finalName)⌘ has not been granted permission to send and receive notifications.\n\nYou can change this in Settings.")
    }

    private func presentRecordingCTA() async -> Bool {
        await presentCTA(with: "⌘\(build.finalName)⌘ needs access to your microphone to record audio messages.\n\nYou can grant this permission in Settings.")
    }

    private func presentTranscriptionCTA() async -> Bool {
        await presentCTA(
            with: "⌘\(build.finalName)⌘ needs speech recognition access to translate audio messages.\n\nYou can grant this permission in Settings."
        )
    }

    @MainActor
    private func presentCTA(with message: String) async -> Bool {
        var cancelled = true

        @Localized(.settings) var settingsString: String
        let settingsURL = URL(string: UIApplication.openSettingsURLString)
        let resolvedSettingsString = settingsString.replacingOccurrences(of: "…", with: "...")

        var actions: [AKAction] = [.cancelAction]
        if let settingsURL,
           uiApplication.canOpenURL(settingsURL) {
            let settingsAction: AKAction = .init(resolvedSettingsString) {
                cancelled = false
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

        return cancelled
    }

    // MARK: - Computed Property Getters

    private func getContactPermissionStatus() -> PermissionStatus {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized,
             .limited:
            return .granted
        case .denied,
             .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
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
            return .granted
        case .denied,
             .restricted:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }
}
