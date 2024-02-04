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

    case avFoundationError = "EA73"
    case contactAccessDenied = "F6E6"
    case couldntRemoveInput = "F9A1"
    case currentUserIDNotSet = "E383"
    case exhaustedAvailablePlatforms = "6005"
    case fileDoesNotExist = "BB00"
    case genericStorageError = "6F00"
    case invalidVerificationCode = "7E4A"
    case kAFAssistantError = "91C7"
    case notAuthorizedForContacts = "16AA"
    case notRegisteredForPushNotifications = "06BE"
    case noAudioRecorderToStop = "A92A"
    case noUserWithHashes = "BD49"
    case noUsersWithPhoneNumbers = "9330"
    case noValueExists = "7CD4"
    case sameTranslationInputOutput = "964B"
    case timedOut = "DE75"
    case transcribeAudioRetry = "B386"
    case transcribeNoSuchFileOrDirectory = "5BBC"
}

/**
 Use this method to add simplified descriptors for commonly encountered errors.
 */
public extension Exception {
    func userFacingDescriptor(for descriptor: String) -> String? {
        switch descriptor {
        /* Add simplified error descriptors here. */
        default:
            return nil
        }
    }
}
