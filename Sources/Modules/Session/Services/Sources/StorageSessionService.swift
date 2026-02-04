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

final class StorageSessionService {
    // MARK: - Dependencies

    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.coreKit.utils.isEnhancedDialogTranslationEnabled) private var isEnhancedDialogTranslationEnabled: Bool
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    static let storageLimitInKilobytes: Double = 10240

    private let warningAlertRatio: Double = 0.6

    @LockIsolated private var isCalculatingDataUsage = false
    private var lastDataUsageCalculation: DataUsageCalculation = .empty

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

    @MainActor // swiftlint:disable:next function_body_length
    func getCurrentUserDataUsage() async -> Callback<Int, Exception> {
        guard !isCalculatingDataUsage,
              lastDataUsageCalculation == DataUsageCalculation.empty ||
              lastDataUsageCalculation.isExpired else {
            Logger.log( // swiftlint:disable:next line_length
                "Returning last known data usage calculation (\(lastDataUsageCalculation.dataUsageInKilobytes)kb), from \(abs(lastDataUsageCalculation.date.seconds(from: .now)))s ago.",
                domain: .storageSession,
                sender: self
            )

            return .success(lastDataUsageCalculation.dataUsageInKilobytes)
        }

        isCalculatingDataUsage = true
        defer { isCalculatingDataUsage = false }
        var dataUsageInKilobytes = 0

        if let exception = await User.populateCurrentUserConversationsIfNeeded() {
            return .failure(exception)
        }

        // Size of user object

        let getSizeOfUserObjectResult = getSizeOfUserObject()

        switch getSizeOfUserObjectResult {
        case let .success(sizeOfUserObject): dataUsageInKilobytes += sizeOfUserObject
        case let .failure(exception): return .failure(exception)
        }

        defer { Logger.closeStream(domain: .storageSession) }
        Logger.openStream(
            message: "Size of user object: \(dataUsageInKilobytes)kb",
            domain: .storageSession,
            sender: self
        )

        // Conversation data size

        let getConversationDataSizeResult = getConversationDataSize()

        switch getConversationDataSizeResult {
        case let .success(conversationDataSize):
            Logger.logToStream(
                "Conversation data usage: \(conversationDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += conversationDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Message data size

        let getMessageDataSizeResult = getMessageDataSize()

        switch getMessageDataSizeResult {
        case let .success(messageDataSize):
            Logger.logToStream(
                "Message data usage: \(messageDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += messageDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Translation data size

        let getTranslationDataSizeResult = getTranslationDataSize()

        switch getTranslationDataSizeResult {
        case let .success(translationDataSize):
            Logger.logToStream(
                "Translation data usage: \(translationDataSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += translationDataSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Combined audio size

        let getCombinedAudioSizeResult = await getCombinedAudioSize()

        switch getCombinedAudioSizeResult {
        case let .success(combinedAudioSize):
            Logger.logToStream(
                "Audio data usage: \(combinedAudioSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += combinedAudioSize

        case let .failure(exception):
            return .failure(exception)
        }

        // Combined media size

        let getCombinedMediaSizeResult = await getCombinedMediaSize()

        switch getCombinedMediaSizeResult {
        case let .success(combinedMediaSize):
            Logger.logToStream(
                "Media data usage: \(combinedMediaSize)kb",
                domain: .storageSession,
                line: #line
            )

            dataUsageInKilobytes += combinedMediaSize

        case let .failure(exception):
            return .failure(exception)
        }

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

        lastDataUsageCalculation = .init(dataUsage: dataUsageInKilobytes)
        return .success(dataUsageInKilobytes)
    }

    // MARK: - Invalidate Data Usage Calculation

    func invalidateDataUsageCalculation() {
        lastDataUsageCalculation = .empty
    }

    // MARK: - Present Storage Warning Alert

    func presentStorageWarningAlert() async {
        guard ((try? (await getCurrentUserDataUsage()).get()) ?? 0) >= Int(
            StorageSessionService.storageLimitInKilobytes * warningAlertRatio
        ) else { return }

        if atOrAboveDataUsageLimit {
            let getStorageFullAlertResult = await getStorageFullAlert()

            switch getStorageFullAlertResult {
            case let .success(storageFullAlert):
                await storageFullAlert.present(translating: [.title])

            case let .failure(exception):
                Logger.log(
                    exception,
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

    private func getCombinedAudioSize() async -> Callback<Int, Exception> {
        let audioFilePaths = getAudioFilePaths()
        return await totalSizeInKilobytes(of: audioFilePaths)
    }

    private func getCombinedMediaSize() async -> Callback<Int, Exception> {
        let mediaFilePaths = getMediaFilePaths()
        return await totalSizeInKilobytes(of: mediaFilePaths)
    }

    private func getConversationDataSize() -> Callback<Int, Exception> {
        guard let encodedConversationData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .map(\.encoded) else {
            return .failure(.init(
                "Failed to resolve encoded conversations.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedConversationData)
    }

    private func getMessageDataSize() -> Callback<Int, Exception> {
        guard let encodedMessageData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .map(\.encoded) else {
            return .failure(.init(
                "Failed to resolve encoded messages.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedMessageData)
    }

    private func getSizeOfUserObject() -> Callback<Int, Exception> {
        guard let encodedUserData = currentUser?.encoded else {
            return .failure(.init(
                "Failed to resolve encoded user data.",
                metadata: .init(sender: self)
            ))
        }

        return sizeInKilobytes(of: encodedUserData)
    }

    private func getTranslationDataSize() -> Callback<Int, Exception> {
        guard let encodedTranslationData = currentUser?
            .conversations?
            .visibleForCurrentUser
            .flatMap({ $0.messages ?? [] })
            .filter({ $0.fromAccountID == User.currentUserID })
            .flatMap({ $0.translationReferences ?? [] })
            .compactMap(\.jsonData) else {
            return .failure(.init(
                "Failed to resolve encoded translations.",
                metadata: .init(sender: self)
            ))
        }

        return .success(Int(
            encodedTranslationData.reduce(into: Double()) { partialResult, datum in
                partialResult += Double(datum.count) / 1024
            }
        ))
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

        return (inputFilePaths ?? []) + (outputFilePaths ?? []).unique
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
    private func getStorageFullAlert() async -> Callback<AKAlert, Exception> {
        let messagePrefixInput = TranslationInput("You can free up space by deleting conversations.")
        let messageSuffixInput = TranslationInput("Until then, you will not be able to send new messages.")

        let getTranslationsResult = await networking.hostedTranslation.getTranslations(
            for: [
                messagePrefixInput,
                messageSuffixInput,
            ],
            languagePair: .system,
            hud: nil,
            enhance: isEnhancedDialogTranslationEnabled ? .init(
                additionalContext: nil
            ) : nil
        )

        switch getTranslationsResult {
        case let .success(translations):
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

            return .success(storageFullAlert)

        case let .failure(exception):
            return .failure(exception)
        }
    }

    private func sizeInKilobytes(of data: Any) -> Callback<Int, Exception> {
        guard JSONSerialization.isValidJSONObject(data) else {
            return .failure(.init(
                "Invalid JSON object.",
                userInfo: ["Data": data],
                metadata: .init(sender: self)
            ))
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return .success(Int(Double(jsonData.count) / 1024))
        } catch {
            return .failure(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    private func totalSizeInKilobytes(of items: [String]) async -> Callback<Int, Exception> {
        var totalSizeInKilobytes = 0

        for filePath in items {
            let sizeInKilobytesResult = await networking.storage.sizeInKilobytes(
                ofItemAt: filePath
            )

            switch sizeInKilobytesResult {
            case let .success(sizeInKilobytes): totalSizeInKilobytes += sizeInKilobytes
            case let .failure(exception): return .failure(exception)
            }
        }

        return .success(totalSizeInKilobytes)
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
