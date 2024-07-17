//
//  OnboardingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class OnboardingService {
    // MARK: - Dependencies

    @Dependency(\.commonServices.notification) private var notificationService: NotificationService
    @Dependency(\.networking.services.user) private var userService: UserService

    // MARK: - Properties

    // PhoneNumber
    public private(set) var phoneNumber: PhoneNumber?

    // String
    public private(set) var authID: String?
    public private(set) var languageCode: String?
    public private(set) var regionCode: String?
    public private(set) var userID: String?

    // MARK: - Setters

    public func setAuthID(_ authID: String) {
        self.authID = authID
    }

    public func setLanguageCode(_ languageCode: String) {
        self.languageCode = languageCode
    }

    public func setPhoneNumber(_ phoneNumber: PhoneNumber) {
        self.phoneNumber = phoneNumber
    }

    public func setRegionCode(_ regionCode: String) {
        self.regionCode = regionCode
    }

    public func setUserID(_ userID: String) {
        self.userID = userID
    }

    // MARK: - Create User

    public func createUser() async -> Exception? {
        guard let languageCode,
              let phoneNumber,
              let userID else {
            return .init(
                "Insufficient data to create user.",
                metadata: [self, #file, #function, #line]
            )
        }

        let createUserResult = await userService.createUser(
            id: userID,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: notificationService.pushToken == nil ? nil : [notificationService.pushToken!]
        )

        switch createUserResult {
        case let .success(user):
            @Persistent(.currentUserID) var currentUserID: String?
            currentUserID = user.id
            return nil

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Alert Presentation

    /// - Returns: `true` if the user selected the cancel option.
    public func presentAccountDoesNotExistAlert() async -> Bool {
        var cancelled = true

        let signUpAction: AKAction = .init("Sign Up", style: .preferred) { cancelled = false }
        await AKAlert(
            message: "There is no account registered with this phone number. Please sign up instead.",
            actions: [
                signUpAction,
                .cancelAction,
            ]
        ).present(translating: [.actions([signUpAction]), .message])

        return cancelled
    }

    /// - Returns: `true` if the user selected the cancel option.
    public func presentAccountExistsAlert() async -> Bool {
        var cancelled = true

        let signInAction: AKAction = .init("Sign In", style: .preferred) { cancelled = false }
        await AKAlert(
            message: "There is already an account registered with this phone number. Please sign in instead.",
            actions: [
                signInAction,
                .cancelAction,
            ]
        ).present(translating: [.actions([signInAction]), .message])

        return cancelled
    }

    /// - Returns: `true` if the user selected the cancel option.
    public func presentEULAAlert() async -> Bool {
        var cancelled = true

        let agreeAction: AKAction = .init("I Agree", style: .preferred) { cancelled = false }
        await AKActionSheet(
            message: "I agree to help maintain a community of respect towards others via my personal conduct on this app.",
            actions: [agreeAction],
            cancelButtonTitle: "I Do Not Agree"
        ).present()

        return cancelled
    }

    // MARK: - Auxiliary

    public func flushValues() {
        authID = nil
        languageCode = nil
        phoneNumber = nil
        regionCode = nil
        userID = nil
    }
}
