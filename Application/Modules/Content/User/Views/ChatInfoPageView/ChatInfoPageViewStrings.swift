//
//  ChatInfoPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/03/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslatedLabelStringCollection {
    enum ChatInfoPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case changeMetadataButtonText = "Change name and photo"
        case participantCountLabelText = "people"

        // MARK: - Properties

        public var alternate: String? {
            switch self {
            case .participantCountLabelText:
                return "persons"

            default:
                return nil
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
