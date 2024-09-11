//
//  ExceptionCatalog.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/**
 Use this extension to catalog application-specific `Exception` types and their corresponding hashlet values.
 */
public extension AppException {
    // MARK: - Types

    struct UserFacingDescriptorDelegate: AppSubsystem.Delegates.UserFacingDescriptorDelegate {
        // swiftlint:disable line_length
        public func userFacingDescriptor(for descriptor: String) -> String? {
            switch descriptor {
            case "Attempted to select contact pair containing blocked user.":
                return "You have blocked this user."

            case "Attempted to select contact pair containing current user.":
                return "Unable to start a conversation with yourself."

            case "The format of the phone number provided is incorrect. Please enter the phone number in a format that can be parsed into E.164 format. E.164 phone numbers are written in the format [+][country code][subscriber number including area code].":
                return "The format of the phone number is incorrect. Please verify that you haven't included the country code."

            case "The multifactor verification code used to create the auth credential is invalid.Re-collect the verification code and be sure to use the verification code provided by the user.":
                return "The verification code is incorrect. Please try again."

            case "The SMS code has expired. Please re-send the verification code to try again.":
                return "The verification code has expired. Please try again."

            default: return nil
            }
        }
        // swiftlint:enable line_length
    }

    // MARK: - Properties

    static let contactAccessDenied: AppException = .init("C8DC")
    static let currentUserIDNotSet: AppException = .init("EA90")
    static let decodingFailed: AppException = .init("20FC")
    static let exhaustedAvailablePlatforms: AppException = .init("C526")
    static let genericStorageError: AppException = .init("C81B")
    static let kAFAssistantError: AppException = .init("F59D")
    static let mismatchedHashAndCallingCode: AppException = .init("D339")
    static let noAudioRecorderToStop: AppException = .init("E44E")
    static let notAuthorizedForContacts: AppException = .init("B7FC")
    static let notRegisteredForPushNotifications: AppException = .init("FB09")
    static let noSpeechDetected: AppException = .init("24F2")
    static let noUserWithHashes: AppException = .init("1181")
    static let noUsersWithPhoneNumbers: AppException = .init("74AA")
    static let noValueExists: AppException = .init("BE3A")
    static let sameTranslationInputOutput: AppException = .init("6CEB")
    static let storageItemDoesNotExist: AppException = .init("9207")
    static let timedOut: AppException = .init("801F")
    static let userDoesNotNeedConversion: AppException = .init("CCAB")

    // TODO: All of the below need regeneration.

    static let avFoundationError: AppException = .init("EA73")
    static let couldntRemoveInput: AppException = .init("F9A1")
    static let transcribeNoSuchFileOrDirectory: AppException = .init("5BBC")
}
