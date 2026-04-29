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

/// The app's localization key type.
///
/// Each case corresponds to a top-level key in the app's
/// localized strings property list. The ``referent`` property
/// converts the camel case name to snake case, so a case named
/// `helloWorld` maps to the property list key `hello_world`.
///
/// To add a new localized string, add a case to this enum and a
/// matching entry to the property list with translations for
/// each supported language. Access the resolved value using the
/// ``Localized`` property wrapper:
///
///     @Localized(.helloWorld) var greeting: String
///
/// - SeeAlso: ``Localized``, ``LocalizationSource``
enum LocalizedStringKey: String, LocalizedStringKeyRepresentable {
    // MARK: - App Cases

    case acknowledgeConsent
    case addedToConversation
    case aiEnhanced
    case attachment
    case audioMessage
    case awaitingConsent

    case blocked
    case blockUser

    case cannotDisplayMessage
    case changedGroupPhoto
    case contacts
    case copy

    case delete
    case deletingData
    case delivered
    case document

    case enable
    case errorReportedSuccessfully

    case finishingUp
    case fromUser
    case fromYou

    case holdDownToRecord

    case image
    case invite

    case language
    case leftConversation
    case loadingData

    // swiftlint:disable:next identifier_name
    case messageRecipientConsentAcknowledgementMessage
    case messageRecipientConsentRequestMessage
    case multiple
    case myAccount

    case newMessage
    case noResults
    case noSpeechDetected
    case notNow

    case offlineMode
    case originalInLanguage

    case people

    case reacted
    case reactionDetails
    case read
    case region
    case removedConversationName
    case removedFromConversation
    case removedGroupPhoto
    case renamedConversation
    case repairingData
    case reportMistranslation
    case reportUser
    case requestConsent
    case retryTranslation

    case saveFile
    case search
    case selectCallingCode
    case selectLanguage
    case settingLanguage
    case slideToCancel
    case someone
    case speak
    case stopSpeaking

    case to
    case today
    case translationInLanguage

    case version
    case video
    case viewAsAudio
    case viewOriginal
    case viewTranscription
    case viewTranslation

    case welcomeToHello

    case you

    // MARK: - Subsystem Cases

    case cancel
    case dismiss
    case done
    case sendFeedback
    case settings
    case tryAgain
    case yesterday

    // MARK: - Properties

    /// The snake case string used to look up the localized value
    /// in the property list.
    var referent: String { rawValue.snakeCased }
}

/// Use this extension to provide a default ``LocalizationSource``
/// for the app's localization keys.
///
/// This constrained initializer lets call sites omit the source
/// parameter. The default source is `.app()`, which reads from a
/// property list in the main bundle named `LocalizedStrings` by
/// default:
///
///     @Localized(.helloWorld) var greeting: String
///
/// To use a different property list name, pass it through
/// ``LocalizationSource/app(plistName:)``. Pass `.subsystem` to
/// resolve a key from AppSubsystem's built-in strings.
///
/// - SeeAlso: ``LocalizationSource``
extension Localized where T == LocalizedStringKey {
    /// Creates a localized string wrapper for the given key.
    ///
    /// - Parameters:
    ///   - key: The localization key to look up.
    ///   - languageCode: The language to resolve the string for.
    ///     Defaults to ``RuntimeStorage/languageCode``.
    ///   - source: The property list and bundle to read from.
    ///     Defaults to `.app()`.
    init(
        _ key: LocalizedStringKey,
        languageCode: String = RuntimeStorage.languageCode,
        source: LocalizationSource = .app()
    ) {
        var source = source
        switch key {
        case .cancel,
             .dismiss,
             .done,
             .sendFeedback,
             .settings,
             .tryAgain,
             .yesterday: source = .subsystem
        default: ()
        }

        self.init(
            key: key,
            languageCode: languageCode,
            source: source
        )
    }
}
