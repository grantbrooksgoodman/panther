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
import Redux

public final class OnboardingService {
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
        @Dependency(\.commonServices.notification) var notificationService: NotificationService
        @Dependency(\.networking.services.user) var userService: UserService

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
            @Persistent(.currentUserID) var currentUserID: UserID?
            currentUserID = user.id
            return nil

        case let .failure(exception):
            return exception
        }
    }
}
