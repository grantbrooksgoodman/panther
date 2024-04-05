//
//  AppConstants+MessageSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum MessageSessionService {
        public static let addMessageDeliveryProgressIncrement: Float = 0.2 // swiftlint:disable:next identifier_name
        public static let createConversationDeliveryProgressIncrement: Float = 0.2
        public static let createMessageDeliveryProgressIncrement: Float = 0.2
        public static let notifyDeliveryProgressIncrement: Float = 0.2
        public static let readToFileDeliveryProgressIncrement: Float = 0.05
        public static let translationDeliveryProgressIncrement: Float = 0.05
        public static let updateValueDeliveryProgressIncrement: Float = 0.2
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum MessageSessionService { // swiftlint:disable:next identifier_name
        public static let audioMessageTranscriptionSucceededNotificationName = "audioMessageTranscriptionSucceeded"
        public static let conversationIDKeyNotificationUserInfoKey = "conversationIDKey"
        public static let inputFileNotificationUserInfoKey = "inputFile"
    }
}
