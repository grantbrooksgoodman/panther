//
//  PermissionPageViewStrings.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension TranslatedLabelStringCollection {
    enum PermissionPageViewStringKey: String, Equatable, CaseIterable, TranslatedLabelStringKey {
        // MARK: - Cases

        case backButtonText = "Back"
        case finishButtonText = "Finish"

        case contactPermissionCapsuleButtonText = "Tap to allow contact access"
        case notificationPermissionCapsuleButtonText = "Tap to allow notifications"

        // swiftlint:disable:next line_length
        case instructionViewSubtitleLabelText = "Finally, grant ⌘Hello⌘ the necessary permissions to work with your device.\n\nThese options can be changed later in Settings."
        case instructionViewTitleLabelText = "Grant Permissions"

        // MARK: - Properties

        public var alternate: String? {
            switch self {
            case .backButtonText:
                return "Go back"

            default:
                return nil
            }
        }
    }
}

public enum PermissionPageViewStrings: TranslatedLabelStrings {
    public static var keyPairs: [TranslationInputMap] {
        TranslatedLabelStringCollection.PermissionPageViewStringKey.allCases
            .map {
                TranslationInputMap(
                    key: .permissionPageView($0),
                    input: .init(
                        $0.rawValue,
                        alternate: $0.alternate
                    )
                )
            }
    }
}
