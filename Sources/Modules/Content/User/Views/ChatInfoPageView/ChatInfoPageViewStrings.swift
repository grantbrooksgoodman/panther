//
//  ChatInfoPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension TranslatedLabelStringCollection {
    enum ChatInfoPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case addContactButtonText = "Add Contact"
        case changeMetadataButtonText = "Change name and photo"
        case leaveConversation = "Leave this Conversation"
        case participantCountLabelText = "people"
        case segmentedControlMediaOptionText = "Attachments"
        case segmentedControlParticipantsOptionText = "Participants"
        case sharePhoneNumberListRowText = "Share Phone Number"

        // MARK: - Properties

        public var alternate: String? {
            switch self {
            case .participantCountLabelText: "persons"
            case .segmentedControlMediaOptionText: "Shared Media"
            default: nil
            }
        }
    }
}

public enum ChatInfoPageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.ChatInfoPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .chatInfoPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
