//
//  StorageSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking
import Translator

final class StorageSessionService: @unchecked Sendable {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    static let storageLimitInKilobytes: Double = 10240

    private static let coalescer = SingleSlotCoalescer<Int>()

    private let warningAlertRatio: Double = 0.6

    @LockIsolated private var isCalculatingDataUsage = false
    @LockIsolated private var lastDataUsageCalculation: DataUsageCalculation = .empty

    // MARK: - Computed Properties

    var atOrAboveDataUsageLimit: Bool {
        lastDataUsageCalculation.dataUsageInKilobytes >= Int(
            StorageSessionService.storageLimitInKilobytes
        )
    }

    var isApproachingDataUsageLimit: Bool {
        lastDataUsageCalculation.dataUsageInKilobytes >= Int(
            StorageSessionService.storageLimitInKilobytes * warningAlertRatio
        )
    }

    // MARK: - Current User Data Usage

    func getCurrentUserDataUsage() async throws(Exception) -> Int {
        try await Self.coalescer { [weak self] () async throws(Exception) -> Int in
            guard let self else {
                throw Exception(
                    "Service has been deallocated.",
                    metadata: .init(sender: Self.self)
                )
            }

            return try await _getCurrentUserDataUsage()
        }
    }

    @MainActor
    private func _getCurrentUserDataUsage() async throws(Exception) -> Int {
        let isDataUsageCalculationInvalid = $lastDataUsageCalculation.withValue { calculation -> Bool in
            calculation == DataUsageCalculation.empty || calculation.isExpired
        }

        guard !isCalculatingDataUsage,
              isDataUsageCalculationInvalid else {
            Logger.log( // swiftlint:disable:next line_length
                "Returning last known data usage calculation (\(lastDataUsageCalculation.dataUsageInKilobytes)kb), from \(abs(lastDataUsageCalculation.date.seconds(from: .now)))s ago.",
                domain: .storageSession,
                sender: self
            )

            return lastDataUsageCalculation.dataUsageInKilobytes
        }

        isCalculatingDataUsage = true
        defer { isCalculatingDataUsage = false }
        var dataUsageInKilobytes = 0

        try await User.populateCurrentUserConversationsIfNeeded()

        // Size of user object

        dataUsageInKilobytes += try getSizeOfUserObject()

        defer { Logger.closeStream(domain: .storageSession) }
        Logger.openStream(
            message: "Size of user object: \(dataUsageInKilobytes)kb",
            domain: .storageSession,
            sender: self
        )

        // Conversation data size

        let conversationDataSize = try getConversationDataSize()
        dataUsageInKilobytes += conversationDataSize
        Logger.logToStream(
            "Conversation data usage: \(conversationDataSize)kb",
            domain: .storageSession,
            line: #line
        )

        // Message data size

        let messageDataSize = try getMessageDataSize()
        dataUsageInKilobytes += messageDataSize
        Logger.logToStream(
            "Message data usage: \(messageDataSize)kb",
            domain: .storageSession,
            line: #line
        )

        // Translation data size

        let translationDataSize = try getTranslationDataSize()
        dataUsageInKilobytes += translationDataSize
        Logger.logToStream(
            "Translation data usage: \(translationDataSize)kb",
            domain: .storageSession,
            line: #line
        )

        // Combined audio size

        let combinedAudioSize = try await getCombinedAudioSize()
        dataUsageInKilobytes += combinedAudioSize
        Logger.logToStream(
            "Audio data usage: \(combinedAudioSize)kb",
            domain: .storageSession,
            line: #line
        )

        // Combined media size

        let combinedMediaSize = try await getCombinedMediaSize()
        dataUsageInKilobytes += combinedMediaSize
        Logger.logToStream(
            "Media data usage: \(combinedMediaSize)kb",
            domain: .storageSession,
            line: #line
        )

        // Aggregate

        Logger.closeStream(
            domain: .storageSession,
            onLine: #line
        )

        let usageInMB = String(
            format: "%.2f",
            Double(dataUsageInKilobytes) / 1024
        )

        Logger.log(
            "Total data usage: \(dataUsageInKilobytes)kb / \(usageInMB)mb",
            domain: .storageSession,
            sender: self
        )

        defer { lastDataUsageCalculation = .init(dataUsage: dataUsageInKilobytes) }
        guard chatPageState.isPresented else {
            Observables.updatedContactPairArchive.trigger()
            return dataUsageInKilobytes
        }

        chatPageState.addEffectUponIsPresented(
            changedTo: false,
            id: .updateAppearance
        ) {
            Observables.updatedContactPairArchive.trigger()
        }

        return dataUsageInKilobytes
    }

    // MARK: - Present Storage Warning Alert

    func presentStorageWarningAlert() async {
        guard await ((try? (getCurrentUserDataUsage())) ?? 0) >= Int(
            StorageSessionService.storageLimitInKilobytes * warningAlertRatio
        ) else { return }

        if atOrAboveDataUsageLimit {
            do {
                try await getStorageFullAlert().present(translating: [
                    .title,
                ])
            } catch {
                Logger.log(
                    error,
                    domain: .storageSession,
                    with: .toastInPrerelease
                )
            }
        } else {
            await AKAlert(
                title: "Storage Almost Full",
                message: "You can free up space by deleting conversations.",
                actions: [.cancelAction(title: "OK")]
            ).present(translating: [
                .message,
                .title,
            ])
        }
    }

    // MARK: - Data Size Calculation

    private func getCombinedAudioSize() async throws(Exception) -> Int {
        try await totalSizeInKilobytes(
            of: getAudioFilePaths()
        )
    }

    private func getCombinedMediaSize() async throws(Exception) -> Int {
        try await totalSizeInKilobytes(
            of: getMediaFilePaths()
        )
    }

    private func getConversationDataSize() throws(Exception) -> Int {
        guard let encodedConversationData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .map(\.encoded) else {
            throw Exception(
                "Failed to resolve encoded conversations.",
                isReportable: false,
                metadata: .init(sender: self)
            )
        }

        return try sizeInKilobytes(of: encodedConversationData)
    }

    private func getMessageDataSize() throws(Exception) -> Int {
        guard let encodedMessageData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .map(\.encoded) else {
            throw Exception(
                "Failed to resolve encoded messages.",
                metadata: .init(sender: self)
            )
        }

        return try sizeInKilobytes(of: encodedMessageData)
    }

    private func getSizeOfUserObject() throws(Exception) -> Int {
        guard let encodedUserData = currentUser?.encoded else {
            throw Exception(
                "Failed to resolve encoded user data.",
                metadata: .init(sender: self)
            )
        }

        return try sizeInKilobytes(of: encodedUserData)
    }

    private func getTranslationDataSize() throws(Exception) -> Int {
        guard let encodedTranslationData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .flatMap({ $0.translationReferences ?? [] })
            .compactMap(\.jsonData) else {
            throw Exception(
                "Failed to resolve encoded translations.",
                metadata: .init(sender: self)
            )
        }

        return Int(
            encodedTranslationData.reduce(into: Double()) { partialResult, datum in
                partialResult += Double(datum.count) / 1024
            }
        )
    }

    // MARK: - Path Enumeration

    private func getAudioFilePaths() -> [String] {
        let localAudioFilePaths = currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap { $0.messages ?? [] }
            .filter { $0.fromAccountID == User.currentUserID }
            .compactMap(\.localAudioFilePath)

        let inputFilePaths = localAudioFilePaths?.map(\.inputFilePathString)
        let outputFilePaths = localAudioFilePaths?.map(\.outputFilePathString)

        return ((inputFilePaths ?? []) + (outputFilePaths ?? [])).unique
    }

    private func getMediaFilePaths() -> [String] {
        currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap { $0.messages ?? [] }
            .filter { $0.fromAccountID == User.currentUserID }
            .compactMap(\.richContent?.mediaComponent?.relativePath)
            .unique ?? []
    }

    // MARK: - Auxiliary

    @MainActor
    private func getStorageFullAlert() async throws(Exception) -> AKAlert {
        let messagePrefixInput = TranslationInput("You can free up space by deleting conversations.")
        let messageSuffixInput = TranslationInput("Until then, you will not be able to send new messages.")

        let translations = try await networking.hostedTranslation.getTranslations(
            for: [
                messagePrefixInput,
                messageSuffixInput,
            ],
            languagePair: .system,
            hud: nil,
            enhance: Networking.config.isEnhancedDialogTranslationEnabled ? .init(
                additionalContext: nil
            ) : nil
        )

        let prefixOutput = (translations.first(where: {
            $0.input.value == messagePrefixInput.value
        })?.output ?? messagePrefixInput.value).sanitized

        let suffixOutput = (translations.first(where: {
            $0.input.value == messageSuffixInput.value
        })?.output ?? messageSuffixInput.value).sanitized

        let storageFullAlert = AKAlert(
            title: "Storage Full",
            message: "\(prefixOutput)\n\n\(suffixOutput)",
            actions: [.cancelAction(title: "OK")]
        )

        let fontSize: CGFloat = UIApplication.isFullyV26Compatible ? 15 : 13
        let attributedMessageFont: UIFont = .systemFont(ofSize: fontSize)

        storageFullAlert.setMessageAttributes(
            .init(
                [.font: attributedMessageFont],
                secondaryAttributes: [.init(
                    [
                        .font: attributedMessageFont,
                        .foregroundColor: UIColor.red,
                    ],
                    stringRanges: [suffixOutput]
                )]
            )
        )

        return storageFullAlert
    }

    private func sizeInKilobytes(
        of data: Any
    ) throws(Exception) -> Int {
        guard JSONSerialization.isValidJSONObject(data) else {
            throw Exception(
                "Invalid JSON object.",
                userInfo: ["Data": data],
                metadata: .init(sender: self)
            )
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return Int(Double(jsonData.count) / 1024)
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    private func totalSizeInKilobytes(
        of items: [String]
    ) async throws(Exception) -> Int {
        try await items.parallelMap { filePath in
            try await self.networking.storage.sizeInKilobytes(
                ofItemAt: filePath
            )
        }.reduce(0, +)
    }
}

private extension TranslationReference {
    var jsonData: Data? {
        @Dependency(\.jsonEncoder) var jsonEncoder: JSONEncoder

        do {
            return try jsonEncoder.encode(self)
        } catch {
            Logger.log(.init(
                error,
                userInfo: ["Data": self],
                metadata: .init(sender: self)
            ))
        }

        return nil
    }
}

// swiftlint:enable file_length type_body_length
