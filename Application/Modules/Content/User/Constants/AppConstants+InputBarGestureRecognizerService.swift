//
//  AppConstants+InputBarGestureRecognizerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

// MARK: - CGFloat

public extension AppConstants.CGFloats {
    enum InputBarGestureRecognizerService {
        public static let errorToastPerpetuationDuration: CGFloat = 3
        public static let longPressGestureMinimumPressDuration: CGFloat = 0.3
        public static let millisecondsDelay: CGFloat = 500 // swiftlint:disable:next identifier_name
        public static let recordingInstructionToastPerpetuationDuration: CGFloat = 2.5
    }
}

// MARK: - String

public extension AppConstants.Strings {
    enum InputBarGestureRecognizerService { // swiftlint:disable:next line_length
        public static let audioMessagesUnsupportedAlertMessage = "Audio messages are unsupported for your language.\n\nPlease check back later in a future update!" // swiftlint:disable:next identifier_name
        public static let audioMessagesUnsupportedAlertCancelButtonTitle = "OK"
        public static let noSpeechDetectedExceptionDescriptor = "No speech detected"
    }
}
