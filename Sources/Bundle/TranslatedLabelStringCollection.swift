//
//  TranslatedLabelStringCollection.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension TranslatedLabelStringCollection {
    /* Add methods here to expose new strings for on-the-fly translation. */

    static func authCodePageView(_ key: AuthCodePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func changeLanguagePageView(_ key: ChangeLanguagePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func chatInfoPageView(_ key: ChatInfoPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func contactSelectorPageView(_ key: ContactSelectorPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func conversationsPageView(_ key: ConversationsPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func inviteQRCodePageView(_ key: InviteQRCodePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func permissionPageView(_ key: PermissionPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func samplePageView(_ key: SamplePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func selectLanguagePageView(_ key: SelectLanguagePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func settingsPageView(_ key: SettingsPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func signInPageView(_ key: SignInPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func verifyNumberPageView(_ key: VerifyNumberPageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
    static func welcomePageView(_ key: WelcomePageViewStringKey) -> TranslatedLabelStringCollection { .init(key.rawValue) }
}
