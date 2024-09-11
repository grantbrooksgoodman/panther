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

/* Proprietary */
import AppSubsystem

@MainActor
public extension RootSheet {
    /* Add values here to expose new views for presentation on the root sheet. */

    static let chatInfoPageView: RootSheet = .init(.init(
        ChatInfoPageView(
            .init(
                initialState: .init(),
                reducer: ChatInfoPageReducer()
            ))
    ))

    static let inviteLanguagePicker: RootSheet = .init(.init(
        InviteLanguagePickerView(
            .init(
                initialState: .init(),
                reducer: InviteLanguagePickerReducer()
            ))
    ))

    static let inviteQRCodePageView: RootSheet = .init(.init(
        InviteQRCodePageView(
            .init(
                initialState: .init(),
                reducer: InviteQRCodePageReducer()
            ))
    ))
}
