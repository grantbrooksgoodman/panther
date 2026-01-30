//
//  LocalizedStringKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum LocalizedStringKey: String, LocalizedStringKeyRepresentable {
    // MARK: - Cases

    /* Add cases here for newly pre-localized strings. */

    case acknowledgeConsent
    case addedToConversation
    case attachment
    case audioMessage
    case awaitingConsent

    case blocked
    case blockUser

    case cancel
    case cannotDisplayMessage
    case changedGroupPhoto
    case contacts
    case copy

    case delete
    case deletingData
    case delivered
    case dismiss
    case document
    case done

    case enable
    case errorReported
    case errorReportedSuccessfully

    case finishingUp
    case friday
    case fromUser
    case fromYou

    case holdDownToRecord

    case image
    case internetConnectionOffline
    case invite

    case language
    case leftConversation
    case loadingData

    // swiftlint:disable:next identifier_name
    case messageRecipientConsentAcknowledgementMessage
    case messageRecipientConsentRequestMessage
    case monday
    case multiple
    case myAccount

    case newMessage
    case noEmail
    case noInternetMessage
    case noInternetTitle
    case noResults
    case noSpeechDetected
    case notNow

    case offlineMode
    case originalInLanguage

    case reacted
    case reactionDetails
    case read
    case region
    case removedConversationName
    case removedFromConversation
    case removedGroupPhoto
    case renamedConversation
    case repairingData
    case reportBug
    case reportMistranslation
    case reportSent
    case reportUser
    case requestConsent
    case retryTranslation

    case saturday
    case saveFile
    case search
    case selectCallingCode
    case selectLanguage
    case sendFeedback
    case settingLanguage
    case settings
    case slideToCancel
    case someone
    case somethingWentWrong
    case speak
    case stopSpeaking
    case sunday

    case tapToReport
    case thursday
    case timedOut
    case to
    case today
    case translationInLanguage
    case tryAgain
    case tuesday

    case version
    case video
    case viewAsAudio
    case viewOriginal
    case viewTranscription
    case viewTranslation

    case wednesday
    case welcomeToHello

    case yesterday
    case you

    // MARK: - Properties

    var referent: String { rawValue.snakeCased }
}

extension Localized where T == LocalizedStringKey {
    init(
        _ key: LocalizedStringKey,
        languageCode: String = RuntimeStorage.languageCode
    ) {
        self.init(key: key, languageCode: languageCode)
    }
}

extension LocalizedStringKey {
    struct LocalizedStringsDelegate: AppSubsystem.Delegates.LocalizedStringsDelegate {
        var cancel: String { Localized(.cancel).wrappedValue }
        var done: String { Localized(.done).wrappedValue }
        var errorReported: String { Localized(.errorReported).wrappedValue }
        var dismiss: String { Localized(.dismiss).wrappedValue }
        var internetConnectionOffline: String { Localized(.internetConnectionOffline).wrappedValue }
        var noEmail: String { Localized(.noEmail).wrappedValue }
        var noInternetMessage: String { Localized(.noInternetMessage).wrappedValue }
        var reportBug: String { Localized(.reportBug).wrappedValue }
        var reportSent: String { Localized(.reportSent).wrappedValue }
        var sendFeedback: String { Localized(.sendFeedback).wrappedValue }
        var settings: String { Localized(.settings).wrappedValue }
        var somethingWentWrong: String { Localized(.somethingWentWrong).wrappedValue }
        var tapToReport: String { Localized(.tapToReport).wrappedValue }
        var timedOut: String { Localized(.timedOut).wrappedValue }
        var tryAgain: String { Localized(.tryAgain).wrappedValue }
        var yesterday: String { Localized(.yesterday).wrappedValue }
    }
}
