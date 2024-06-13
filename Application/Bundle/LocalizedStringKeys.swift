//
//  LocalizedStringKeys.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum LocalizedStringKey: String {
    // MARK: - Cases

    /* Add cases here for newly pre-localized strings. */

    case audioMessage

    case cancel
    case contacts
    case copy

    case delete
    case delivered
    case dismiss
    case done

    case errorReportedSuccessfully

    case friday

    case holdDownToRecord

    case internetConnectionOffline
    case invite

    case language

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

    case read
    case rebuildingIndices
    case region
    case reportBug

    case saturday
    case search
    case selectCallingCode
    case selectLanguage
    case sendFeedback
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
    case tryAgain
    case tuesday

    case version
    case viewAsAudio
    case viewOriginal
    case viewTranscription
    case viewTranslation

    case wednesday

    case yesterday

    // MARK: - Properties

    public var referent: String { rawValue.snakeCased }
}
