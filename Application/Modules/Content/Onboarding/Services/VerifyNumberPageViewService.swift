//
//  VerifyNumberPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import Redux

public struct VerifyNumberPageViewService {
    // MARK: - Dependencies

    @Dependency(\.networking.services.user) private var userService: UserService

    // MARK: - Methods

    public func accountExists(for phoneNumber: PhoneNumber) async -> Bool {
        let getUserIDKeysResult = await userService.getUserIDKeys(phoneNumber: phoneNumber)

        switch getUserIDKeysResult {
        case .success:
            return true

        case let .failure(exception):
            Logger.log(exception)
            return false
        }
    }

    /// - Returns: `true` if the user selected the cancel option.
    public func presentAccountExistsAlert() async -> Bool {
        let alert: AKAlert = .init(
            message: "It appears you already have an account. Please sign in instead.",
            actions: [.init(title: "Sign In", style: .preferred)]
        )

        let actionID = await alert.present()
        return actionID == -1
    }
}
