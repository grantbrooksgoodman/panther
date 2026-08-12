//
//  OnboardingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem

/// An object that carries state through the onboarding flow and finalizes account creation.
///
/// Use ``OnboardingService`` to share values gathered across the onboarding pages – the user's
/// language, phone number, region, and authentication identifiers – without threading them through
/// each page's state. Resolve the service through the `\.onboardingService` dependency; the
/// dependency system caches the resolved instance, so every page in the flow reads and writes the
/// same values.
///
/// The service supports both onboarding paths:
///
/// - For sign-up, each page records its result with the corresponding setter as the user
///   progresses. When all required values are present, ``createUser()`` creates the account.
/// - For sign-in, the recorded phone number and region let a page restore the user's prior input
///   when they navigate back through the flow.
///
/// The service also presents the flow's confirmation alerts, such as when the given phone number
/// is already registered, and reports the user's selection to the caller.
///
/// - Important: Recorded values persist for the lifetime of the resolved instance. Call
///   ``flushValues()`` when the user restarts the flow so a previous attempt's values do not leak
///   into the next one.
///
/// - Warning: ``OnboardingService`` does not synchronize access to its stored properties. Access
///   the service from a single concurrency context, such as the reducers that drive the
///   onboarding pages.
final class OnboardingService {
    // MARK: - Dependencies

    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.networking.userService) private var userService: UserService

    // MARK: - Properties

    /// The identifier issued when a verification code was sent to the user's phone number, or
    /// `nil` if verification has not begun.
    ///
    /// Pass this value, along with the code the user enters, to complete authentication.
    private(set) var authID: String?

    /// A Boolean value that indicates whether ``createUser()`` completed successfully during the
    /// current app session.
    ///
    /// Use this value to distinguish a newly created account from a returning sign-in.
    ///
    /// - Note: ``flushValues()`` does not reset this value.
    private(set) var createdUserInCurrentAppSession = false

    /// The language code the user selected during onboarding, or `nil` if one has not been
    /// recorded.
    private(set) var languageCode: String?

    /// The phone number the user entered during onboarding, or `nil` if one has not been
    /// recorded.
    private(set) var phoneNumber: PhoneNumber?

    /// The region code associated with the user's phone number, or `nil` if one has not been
    /// recorded.
    ///
    /// Use this value to restore the user's region selection when they return to a phone number
    /// entry page.
    private(set) var regionCode: String?

    /// The authenticated user's identifier, or `nil` if authentication has not completed.
    ///
    /// ``createUser()`` creates the account's user record under this identifier.
    private(set) var userID: String?

    // MARK: - Setters

    /// Records the identifier issued when a verification code was sent to the user's phone
    /// number.
    ///
    /// - Parameter authID: The identifier to record.
    func setAuthID(_ authID: String) {
        self.authID = authID
    }

    /// Records the language code the user selected.
    ///
    /// - Parameter languageCode: The language code to record.
    func setLanguageCode(_ languageCode: String) {
        self.languageCode = languageCode
    }

    /// Records the phone number the user entered.
    ///
    /// - Parameter phoneNumber: The phone number to record.
    func setPhoneNumber(_ phoneNumber: PhoneNumber) {
        self.phoneNumber = phoneNumber
    }

    /// Records the region code associated with the user's phone number.
    ///
    /// - Parameter regionCode: The region code to record.
    func setRegionCode(_ regionCode: String) {
        self.regionCode = regionCode
    }

    /// Records the authenticated user's identifier.
    ///
    /// - Parameter userID: The identifier to record.
    func setUserID(_ userID: String) {
        self.userID = userID
    }

    // MARK: - Create User

    /// Creates a user record from the values recorded during onboarding.
    ///
    /// Call this method at the end of the sign-up flow, after ``languageCode``, ``phoneNumber``,
    /// and ``userID`` have all been recorded. The method creates the user record under ``userID``,
    /// including the device's current push token when one is available, then persists the new
    /// record's identifier as the signed-in user's ID.
    ///
    /// If the operation succeeds, the method sets ``createdUserInCurrentAppSession`` to `true`
    /// and logs a sign-up analytics event.
    ///
    /// - Throws: An `Exception` if any required value has not been recorded, or if creating the
    ///   user record fails.
    func createUser() async throws(Exception) {
        guard let languageCode,
              let phoneNumber,
              let userID else {
            throw Exception(
                "Insufficient data to create user.",
                metadata: .init(sender: self)
            )
        }

        @Persistent(.currentUserID) var currentUserID: String?
        currentUserID = try await userService.createUser(
            id: userID,
            languageCode: languageCode,
            phoneNumber: phoneNumber,
            pushTokens: services.pushToken.currentToken == nil ? nil : [services.pushToken.currentToken!]
        ).id
        createdUserInCurrentAppSession = true
        services.analytics.logEvent(.signUp)
    }

    // MARK: - Alert Presentation

    /// Presents an alert informing the user that no account is registered with their phone
    /// number, offering to sign up instead.
    ///
    /// Call this method from the sign-in flow when authentication reveals that the given phone
    /// number has no account. The method suspends until the user dismisses the alert.
    ///
    /// - Returns: `true` if the user selected the cancel option; otherwise, `false`, indicating
    ///   the user chose to sign up.
    func presentAccountDoesNotExistAlert() async -> Bool {
        let cancelled = LockIsolated(true)
        let signUpAction: AKAction = .init(
            "Sign Up",
            style: .preferred
        ) {
            cancelled.wrappedValue = false
        }

        await AKAlert(
            message: "There is no account registered with this phone number. Please sign up instead.",
            actions: [
                signUpAction,
                .cancelAction,
            ]
        ).present(translating: [
            .actions([signUpAction]),
            .message,
        ])

        return cancelled.wrappedValue
    }

    /// Presents an alert informing the user that an account is already registered with their
    /// phone number, offering to sign in instead.
    ///
    /// Call this method from the sign-up flow when the given phone number already has an account.
    /// The method suspends until the user dismisses the alert.
    ///
    /// - Returns: `true` if the user selected the cancel option; otherwise, `false`, indicating
    ///   the user chose to sign in.
    func presentAccountExistsAlert() async -> Bool {
        let cancelled = LockIsolated(true)
        let signInAction: AKAction = .init(
            "Sign In",
            style: .preferred
        ) {
            cancelled.wrappedValue = false
        }

        await AKAlert(
            message: "There is already an account registered with this phone number. Please sign in instead.",
            actions: [
                signInAction,
                .cancelAction,
            ]
        ).present(translating: [
            .actions([signInAction]),
            .message,
        ])

        return cancelled.wrappedValue
    }

    /// Presents an action sheet asking the user to agree to the app's conduct policy.
    ///
    /// Call this method before finalizing sign-up. The method suspends until the user dismisses
    /// the sheet.
    ///
    /// - Returns: `true` if the user declined the agreement; otherwise, `false`, indicating the
    ///   user agreed.
    func presentEULAAlert() async -> Bool {
        let cancelled = LockIsolated(true)
        let agreeAction: AKAction = .init(
            "I Agree",
            style: .preferred
        ) {
            cancelled.wrappedValue = false
        }

        await AKActionSheet(
            message: "I agree to help maintain a community of respect towards others via my personal conduct on this app.",
            actions: [agreeAction],
            cancelButtonTitle: "I Do Not Agree",
            sourceItem: .custom(.string(
                "Finish".localized
            ))
        ).present()

        return cancelled.wrappedValue
    }

    // MARK: - Auxiliary

    /// Resets every recorded onboarding value to `nil`.
    ///
    /// Call this method when the user restarts the onboarding flow so values recorded during a
    /// previous attempt do not carry over.
    ///
    /// - Note: This method does not reset ``createdUserInCurrentAppSession``, which reflects the
    ///   entire app session.
    func flushValues() {
        authID = nil
        languageCode = nil
        phoneNumber = nil
        regionCode = nil
        userID = nil
    }
}
