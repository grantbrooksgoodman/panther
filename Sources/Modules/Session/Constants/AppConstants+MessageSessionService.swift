//
//  AppConstants+MessageSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum MessageSessionService {
        static let addMessageDeliveryProgressIncrement: Float = 0.2 // swiftlint:disable:next identifier_name
        static let createConversationDeliveryProgressIncrement: Float = 0.2
        static let createMessageDeliveryProgressIncrement: Float = 0.2 // swiftlint:disable:next identifier_name
        static let languageRecognitionServiceMatchConfidenceThreshold: Float = 0.8
        static let notifyDeliveryProgressIncrement: Float = 0.2
        static let readToFileDeliveryProgressIncrement: Float = 0.05
        static let translationDeliveryProgressIncrement: Float = 0.05
        static let updateValueDeliveryProgressIncrement: Float = 0.2
    }
}

// MARK: - String

extension AppConstants.Strings {
    enum MessageSessionService { // swiftlint:disable:next identifier_name
        static let audioMessageTranscriptionSucceededNotificationName = "audioMessageTranscriptionSucceeded"
        static let conversationIDKeyNotificationUserInfoKey = "conversationIDKey"
        static let inputFileNotificationUserInfoKey = "inputFile" // swiftlint:disable:next identifier_name
        static let isPenPalsConversationNotificationUserInfoKey = "isPenPalsConversation"
    }
}
