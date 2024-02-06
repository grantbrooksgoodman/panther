//
//  ExceptionCatalog.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

/**
 Use this enum to catalog application-specific `Exception` types and their corresponding hashlet values.
 */
public enum AppException: String {
    /* Add new cases here. */

    case currentUserIDNotSet = "EA90"
    case exhaustedAvailablePlatforms = "C526"
    case fileDoesNotExist = "9207"
    case genericStorageError = "C81B"
    case kAFAssistantError = "F59D"
    case noAudioRecorderToStop = "E44E"
    case notAuthorizedForContacts = "B7FC"
    case notRegisteredForPushNotifications = "FB09"
    case noSpeechDetected = "24F2"
    case noUserWithHashes = "1181"
    case noUsersWithPhoneNumbers = "74AA"
    case noValueExists = "BE3A"
    case sameBadgeNumber = "E1C7"
    case sameTranslationInputOutput = "6CEB"
    case timedOut = "801F"

    // FIXME: All of the below need regeneration.

    case avFoundationError = "EA73"
    case contactAccessDenied = "F6E6"
    case couldntRemoveInput = "F9A1"
    case transcribeNoSuchFileOrDirectory = "5BBC"
}

/**
 Use this method to add simplified descriptors for commonly encountered errors.
 */
public extension Exception {
    func userFacingDescriptor(for descriptor: String) -> String? {
        // swiftlint:disable line_length
        switch descriptor {
        case "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code].":
            return "The format of the phone number is incorrect. Please verify that you haven't included the country code."

        case "The multifactor verification code used to create the auth credential is invalid.Re-collect the verification code and be sure to use the verification code provided by the user.":
            return "The verification code is incorrect. Please try again."

        case "The SMS code has expired. Please re-send the verification code to try again.":
            return "The verification code has expired. Please try again."

        default:
            return nil
        }
        // swiftlint:enable line_length
    }
}
