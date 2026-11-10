//
//  StagedText.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A predefined message text used to stage sample conversations during development.
///
/// Each case carries its canonical English text only. The staging service translates
/// that text into the sender's language at staging time, and forces the English
/// recipients' translation back to the canonical text. No per-language strings are
/// required to stage conversations in a new language.
enum StagedText: CaseIterable {
    // MARK: - Cases

    /// The staged reply describing how to download the app.
    case appStoreDownload

    /// The staged audio caption thanking a participant for their praise.
    case appStoreThanks

    /// The staged reply describing phone-number verification.
    case appStoreVerify

    /// The staged message inviting a participant to see the view at the beach.
    case beachDayCheckOut

    /// The staged message offering to get a table.
    case beachDayTable

    /// The staged greeting that opens a PenPals conversation.
    case penPalsGreeting

    /// The staged message thanking a participant for organizing.
    case vacationPlanning

    /// The staged greeting used to demonstrate viewing an original message.
    case viewOriginalGreeting

    /// The staged incoming reply used to demonstrate viewing an original message.
    case viewOriginalIncoming

    /// The staged follow-up used to demonstrate viewing an original message.
    case viewOriginalMeantime

    // MARK: - Properties

    /// The canonical English text.
    var englishText: String {
        switch self {
        case .appStoreDownload: "It\u{2019}s easy! Just download it from the App Store and enter your phone number. That\u{2019}s it!"
        case .appStoreThanks: "Thanks!"
        case .appStoreVerify: "Nope! Just verify your phone number, and you\u{2019}ll be ready to chat!"
        case .beachDayCheckOut: "Check out the view at the beach!"
        case .beachDayTable: "I\u{2019}ll get us a table. See you soon!"
        case .penPalsGreeting: "Hey everyone! Where are you all from?"
        case .vacationPlanning: "Thanks for organizing!"
        case .viewOriginalGreeting: "Hey, it was great to meet you the other day! Hope you had a good flight home."
        case .viewOriginalIncoming: "Thanks, I had a lot of fun. I hope to see you again soon!"
        case .viewOriginalMeantime: "Likewise \u{2013} and in the meantime, we can chat on Hello! \u{1F603}"
        }
    }
}
