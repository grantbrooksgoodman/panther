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

public enum LocalizedStringKey: String, LocalizedStringKeyRepresentable {
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
    case contacts
    case copy

    case delete
    case deletingData
    case delivered
    case dismiss
    case document
    case done

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

    case offlineMode
    case originalInLanguage

    case reacted
    case reactionDetails
    case read
    case region
    case removedFromConversation
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

    public var referent: String { rawValue.snakeCased }
}

public extension Localized where T == LocalizedStringKey {
    init(
        _ key: LocalizedStringKey,
        languageCode: String = RuntimeStorage.languageCode
    ) {
        self.init(key: key, languageCode: languageCode)
    }
}

public extension LocalizedStringKey {
    struct LocalizedStringsDelegate: AppSubsystem.Delegates.LocalizedStringsDelegate {
        public var cancel: String { Localized(.cancel).wrappedValue }
        public var done: String { Localized(.done).wrappedValue }
        public var errorReported: String { Localized(.errorReported).wrappedValue }
        public var dismiss: String { Localized(.dismiss).wrappedValue }
        public var internetConnectionOffline: String { Localized(.internetConnectionOffline).wrappedValue }
        public var noEmail: String { Localized(.noEmail).wrappedValue }
        public var noInternetMessage: String { Localized(.noInternetMessage).wrappedValue }
        public var reportBug: String { Localized(.reportBug).wrappedValue }
        public var reportSent: String { Localized(.reportSent).wrappedValue }
        public var sendFeedback: String { Localized(.sendFeedback).wrappedValue }
        public var settings: String { Localized(.settings).wrappedValue }
        public var somethingWentWrong: String { Localized(.somethingWentWrong).wrappedValue }
        public var tapToReport: String { Localized(.tapToReport).wrappedValue }
        public var timedOut: String { Localized(.timedOut).wrappedValue }
        public var tryAgain: String { Localized(.tryAgain).wrappedValue }
        public var yesterday: String { Localized(.yesterday).wrappedValue }
    }
}
