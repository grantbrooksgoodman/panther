//
//  MessageRetranslationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking
import Translator

@MainActor
struct MessageRetranslationService {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.networking.conversationService.archive) private var conversationArchive: ConversationArchiveService
    @Dependency(\.conversationsPageViewService) private var conversationsPageViewService: ConversationsPageViewService
    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.build.isDeveloperModeEnabled) private var isDeveloperModeEnabled: Bool
    @Dependency(\.languageRecognitionService) private var languageRecognitionService: LanguageRecognitionService
    @Dependency(\.translationArchiverDelegate) private var localTranslationArchiver: TranslationArchiverDelegate
    @Dependency(\.translationService) private var translator: TranslationService

    // MARK: - Properties

    @Persistent(.retranslatedMessageIDs) private var retranslatedMessageIDs: [String: Set<TranslationPlatform>]?

    // MARK: - Retranslate Message in Current Conversation

    // swiftlint:disable:next function_body_length
    func retranslateMessageInCurrentConversation(
        _ message: Message,
        indexPath: IndexPath
    ) async -> Exception? {
        guard chatPageState.isPresented,
              let translation = message.translation,
              let conversation = clientSession.conversation.fullConversation,
              conversation.messageIDs.contains(message.id),
              conversation.messages?.compactMap(\.id).contains(message.id) == true else {
            return .init(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        let targetLanguageCode = translation.languagePair.to
        if await languageRecognitionService.matchConfidence(
            for: translation.output,
            inLanguage: targetLanguageCode
        ) == 1 {
            guard await confirmRetranslation(
                targetLanguageCode: targetLanguageCode,
                messageIsFromCurrentUser: message.isFromCurrentUser
            ) else { return nil }
        }

        coreHUD.showProgress(isModal: true)
        defer { coreHUD.hide() }

        var attemptedPlatforms: Set<TranslationPlatform> = Set(retranslatedMessageIDs?[message.id] ?? [])
        while let platform = TranslationPlatform
            .allCases
            .sorted(by: { $0.orderValue < $1.orderValue })
            .first(where: { !attemptedPlatforms.contains($0) }) {
            if isDeveloperModeEnabled {
                coreHUD.showProgress(
                    text: "Trying \(platform.name)…",
                    isModal: true
                )
            }

            localTranslationArchiver.removeValue(
                inputValueEncodedHash: translation.input.value.encodedHash,
                languagePair: translation.languagePair
            )

            let translateResult = await translator.translate(
                translation.input,
                languagePair: translation.languagePair,
                platform: platform
            )

            attemptedPlatforms.insert(platform)
            if var retranslatedMessageIDs {
                retranslatedMessageIDs[message.id] = attemptedPlatforms
                self.retranslatedMessageIDs = retranslatedMessageIDs
            } else {
                retranslatedMessageIDs = [message.id: [platform]]
            }

            switch translateResult {
            case let .success(newTranslation):
                guard await !isLowQualityTranslationResult(
                    old: translation,
                    new: newTranslation,
                    targetLanguageCode: targetLanguageCode
                ) else { continue }

                @Dependency(\.networking.database) var database: DatabaseDelegate
                if let exception = await database.updateChildValues(
                    forKey: "\(NetworkPath.translations.rawValue)/\(translation.languagePair.string)",
                    with: [
                        translation.reference.type.key: "\(translation.input.value.alphaEncoded)–\(newTranslation.output.alphaEncoded)",
                    ]
                ) {
                    return exception
                }

                if let exception = await conversation.setMessages(ids: [message.id]) {
                    return exception
                }

                clientSession.conversation.setCurrentConversation(conversation)
                chatPageViewService.reloadItemsWhenSafe(
                    at: [indexPath],
                    animated: false
                )

                chatPageState.addEffectUponIsPresented(
                    changedTo: false,
                    id: .markConversationStale
                ) {
                    Task { @MainActor in
                        if let exception = await markStale(
                            conversation,
                            messageID: message.id
                        ) {
                            Logger.log(exception, with: .toast)
                        }
                    }
                }

                showSuccessToast(
                    translationReferenceHostingKey: translation.reference.hostingKey,
                    sameRetranslationResult: false
                )

                return nil

            case let .failure(error):
                let exception = Exception(error, metadata: .init(sender: self))
                guard !exception.isEqual(to: .translationPlatformNotSupported) else { continue }
                return exception
            }
        }

        try? await Task.sleep(for: .milliseconds(350))
        showSuccessToast(
            translationReferenceHostingKey: translation.reference.hostingKey,
            sameRetranslationResult: true
        )

        return nil
    }

    // MARK: - Auxiliary

    private func isLowQualityTranslationResult(
        old oldTranslation: Translation,
        new newTranslation: Translation,
        targetLanguageCode: String
    ) async -> Bool {
        guard oldTranslation.output.normalized != newTranslation.output.normalized else { return true }
        return await languageRecognitionService.matchConfidence(
            for: newTranslation.output,
            inLanguage: targetLanguageCode
        ) < 0.8
    }

    private func showSuccessToast(
        translationReferenceHostingKey: String,
        sameRetranslationResult: Bool
    ) {
        var message = "Successfully retranslated\(RuntimeStorage.languageCode == "en" ? " " : " this ")message."
        let title = message
        if sameRetranslationResult {
            message = "No changes were made. Tap to report a mistranslation."
        }

        var toastAction: (@Sendable () -> Void)? {
            guard sameRetranslationResult,
                  let reportDelegate = alertKitConfig.reportDelegate else { return nil }

            let exception = Exception(
                "A mistranslation has been reported (\(translationReferenceHostingKey.shortCode)).",
                userInfo: [
                    "Descriptor": "A mistranslation has been reported.",
                    "HostedOverrideErrorCode": "CA45",
                    "ReferenceHostingKey": translationReferenceHostingKey,
                ],
                metadata: .init(sender: self)
            )

            return { @Sendable in
                reportDelegate.fileReport(exception)
            }
        }

        Task.delayed(by: .milliseconds(500)) { @MainActor in
            Toast.show(
                .init(
                    .banner(style: .success),
                    title: sameRetranslationResult ? title : nil,
                    message: message,
                    perpetuation: .ephemeral(.seconds(sameRetranslationResult ? 10 : 5))
                ),
                translating: Toast.TranslationOptionKey.allCases,
                onTap: toastAction
            )
        }
    }

    private func confirmRetranslation(
        targetLanguageCode: String,
        messageIsFromCurrentUser: Bool
    ) async -> Bool {
        var languageName = targetLanguageCode.englishLanguageName ?? targetLanguageCode.languageName ?? targetLanguageCode.uppercased()
        if !messageIsFromCurrentUser,
           targetLanguageCode == clientSession.user.currentUser?.languageCode {
            languageName = "your language"
        }

        var alertMessage = "This message appears to be in \(languageName) already."
        if !messageIsFromCurrentUser,
           targetLanguageCode != clientSession.user.currentUser?.languageCode,
           clientSession.user.currentUser?.previousLanguageCodes?.isBangQualifiedEmpty == false {
            alertMessage += "\n\nMessages sent or received while using a previous language setting will not be retranslated into your new current language."
        }

        return await AKConfirmationAlert(
            title: "\(Localized(.retryTranslation).wrappedValue)?",
            message: alertMessage,
            cancelButtonTitle: Localized(.cancel).wrappedValue
        ).present(translating: [
            .confirmButtonTitle,
            .message,
        ])
    }

    private func markStale(
        _ conversation: Conversation,
        messageID: String
    ) async -> Exception? {
        conversationArchive.addValue(
            .init(
                .init(
                    key: conversation.id.key,
                    hash: .init(Int.random(in: 1 ... 1_000_000)).encodedHash
                ),
                activities: conversation.activities,
                messageIDs: conversation.messageIDs.filter { $0 != messageID },
                messages: conversation.messages?.filter { $0.id != messageID },
                metadata: conversation.metadata,
                participants: conversation.participants,
                reactionMetadata: conversation.reactionMetadata,
                users: conversation.users
            )
        )

        var exceptions = [Exception]()

        let updateValueResult = await conversation.updateValue(
            conversation.metadata.copyWith(lastModifiedDate: .now),
            forKey: .metadata
        )

        switch updateValueResult {
        case .success: ()
        case let .failure(exception): exceptions.append(exception)
        }

        let reloadDataResult = await conversationsPageViewService.reloadData()

        switch reloadDataResult {
        case .success: ()
        case let .failure(exception): exceptions.append(exception)
        }

        return exceptions.compiledException
    }
}

private extension String {
    var alphaEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? self
    }

    var normalized: String {
        lowercasedTrimmingWhitespaceAndNewlines.sanitized
    }
}

private extension TranslationPlatform {
    var name: String {
        switch self {
        case .deepL: "DeepL"
        case .google: "Google"
        case .reverso: "Reverso"
        }
    }

    var orderValue: Int {
        switch self {
        case .deepL: 0
        case .google: 2
        case .reverso: 1
        }
    }
}
