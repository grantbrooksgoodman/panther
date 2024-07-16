//
//  InviteQRCodePageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslatedLabelStringCollection {
    enum InviteQRCodePageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case instructionLabelText = "Scan to download ⌘Hello⌘"

        // MARK: - Properties

        public var alternate: String? { nil }
    }
}

public enum InviteQRCodePageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.InviteQRCodePageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .inviteQRCodePageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
