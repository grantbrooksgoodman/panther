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

    case cancel
    case copy

    case delete
    case dismiss
    case done

    case multiple

    case noEmail
    case noInternetMessage
    case noInternetTitle
    case noResults

    case reportBug
    case somethingWentWrong
    case tapToReport
    case timedOut
    case tryAgain

    case search
    case selectCallingCode
    case selectLanguage
    case sendFeedback
    case settings

    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    case today
    case yesterday

    case version

    // MARK: - Properties

    public var referent: String { rawValue.snakeCased }
}
