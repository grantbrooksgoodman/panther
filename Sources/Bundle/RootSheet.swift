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
    // MARK: - Properties

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

    static let reactionDetailsPageView: RootSheet = .init(.init(
        ReactionDetailsPageView(
            .init(
                initialState: .init(),
                reducer: ReactionDetailsPageReducer()
            )
        )
    ))

    // MARK: - Methods

    static func featurePermissionPageView(
        _ configurations: [FeaturePermissionPageView.Configuration]
    ) -> RootSheet {
        .init(.init(
            FeaturePermissionPageView(
                .init(
                    initialState: .init(configurations),
                    reducer: FeaturePermissionPageReducer()
                ))
        ))
    }
}
