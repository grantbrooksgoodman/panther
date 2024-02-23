//
//  RootSheet.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public enum RootSheet {
    // MARK: - Cases

    /* Add cases here to expose new views for presentation on the root sheet. */

    case inviteLanguagePicker

    // MARK: - Properties

    @MainActor
    public var view: AnyView {
        switch self {
        case .inviteLanguagePicker:
            return .init(
                InviteLanguagePickerView(
                    .init(
                        initialState: .init(),
                        reducer: InviteLanguagePickerReducer()
                    )
                )
            )
        }
    }
}
