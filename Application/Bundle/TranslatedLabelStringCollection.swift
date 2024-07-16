//
//  TranslatedLabelStringCollection.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum TranslatedLabelStringCollection: Equatable {
    /* Add cases here to expose new strings for on-the-fly translation. */

    case authCodePageView(AuthCodePageViewStringKey)
    case chatInfoPageView(ChatInfoPageViewStringKey)
    case conversationsPageView(ConversationsPageViewStringKey)
    case inviteQRCodePageView(InviteQRCodePageViewStringKey)
    case permissionPageView(PermissionPageViewStringKey)
    case samplePageView(SamplePageViewStringKey)
    case selectLanguagePageView(SelectLanguagePageViewStringKey)
    case settingsPageView(SettingsPageViewStringKey)
    case signInPageView(SignInPageViewStringKey)
    case verifyNumberPageView(VerifyNumberPageViewStringKey)
    case welcomePageView(WelcomePageViewStringKey)
}
