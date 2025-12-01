//
//  RootSheet.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 22/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

@MainActor
extension RootSheet {
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

    static let penPalsPermissionPageView: RootSheet = .init(.init(
        PenPalsPermissionPageView(
            .init(
                initialState: .init(),
                reducer: PenPalsPermissionPageReducer()
            ))
    ))

    static let reactionDetailsPageView: RootSheet = .init(.init(
        ReactionDetailsPageView(
            .init(
                initialState: .init(),
                reducer: ReactionDetailsPageReducer()
            )
        )
    ))
}
