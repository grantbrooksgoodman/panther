//
//  SettingsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Contacts
import Foundation
import SwiftUI

/* 3rd-party */
import AlertKit
import Redux

public struct SettingsPageViewService {
    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.hud) private var coreHUD: CoreKit.HUD
    @Dependency(\.commonServices.contact) private var contactService: ContactService
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Public

    public func developerModeListItems() -> [StaticListItem]? {
        typealias Colors = AppConstants.Colors.SettingsPageView
        typealias Strings = AppConstants.Strings.SettingsPageView

        guard build.stage != .generalRelease else { return nil }

        var items = [StaticListItem]()

        if build.developerModeEnabled,
           let currentUser = userSession.currentUser,
           currentUser.languageCode != "en" {
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            let restoreLanguageCodeString = "\(Strings.restoreLanguageCodeButtonTextPrefix) \(languageName)"
            let overrideOrRestore = akCore.languageCodeIsLocked ? restoreLanguageCodeString : Strings.overrideLanguageCodeButtonText

            items.append(
                .init(
                    title: overrideOrRestore,
                    imageData: (.init(systemName: Strings.overrideLanguageCodeButtonImageSystemName), Colors.overrideLanguageCodeButtonImageForeground),
                    action: overrideLanguageCodeButtonTapped
                )
            )
        }

        if !build.developerModeEnabled {
            items.append(
                .init(
                    title: Strings.toggleDeveloperModeButtonText,
                    imageData: (.init(systemName: Strings.toggleDeveloperModeButtonImageSystemName), Colors.toggleDeveloperModeButtonImageForeground),
                    action: { DevModeService.promptToToggle() }
                )
            )
        }

        return items
    }

    public func fetchCnContactForCurrentUser() async -> Callback<CNContact, Exception> {
        guard let currentUser = userSession.currentUser else {
            return .failure(.init(
                "Current user has not been set.",
                metadata: [self, #file, #function, #line]
            ))
        }

        return await contactService.firstCnContact(for: currentUser.phoneNumber)
    }

    // MARK: - Private

    private func overrideLanguageCodeButtonTapped() {
        guard !akCore.languageCodeIsLocked else {
            RuntimeStorage.remove(.overriddenLanguageCode)
            akCore.unlockLanguageCode(andSetTo: RuntimeStorage.languageCode)

            guard let currentUser = userSession.currentUser else { return }
            let languageName = currentUser.languageCode.languageExonym ?? currentUser.languageCode.uppercased()
            coreHUD.showSuccess(text: "Set to \(languageName)")

            return
        }

        akCore.lockLanguageCode(to: "en")
        RuntimeStorage.store("en", as: .overriddenLanguageCode)
        coreHUD.showSuccess(text: "Set to English")
    }
}
