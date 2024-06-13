//
//  Auth.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import FirebaseAuth

public struct Auth {
    // MARK: - Dependencies

    @Dependency(\.networking.delegates) private var delegates: NetworkDelegates
    @Dependency(\.firebaseAuth) private var firebaseAuth: FirebaseAuth.Auth
    @Dependency(\.firebasePhoneAuthProvider) private var phoneAuthProvider: PhoneAuthProvider

    // MARK: - Authentication with Verification Code

    /// - Returns: On success, a string representing the user's ID.
    public func authenticateUser(
        authID: String,
        verificationCode: String
    ) async -> Callback<String, Exception> {
        guard delegates.connectionStatusProvider.isOnline else {
            return .failure(.internetConnectionOffline([self, #file, #function, #line]))
        }

        delegates.activityIndicator.show()

        let credential = phoneAuthProvider.credential(withVerificationID: authID, verificationCode: verificationCode)

        do {
            let signInResult = try await firebaseAuth.signIn(with: credential)
            delegates.activityIndicator.hide()
            return .success(signInResult.user.uid)
        } catch {
            delegates.activityIndicator.hide()
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Phone Number Verification

    /// - Returns: On success, a string representing the phone number verification ID.
    public func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String = RuntimeStorage.languageCode
    ) async -> Callback<String, Exception> {
        guard delegates.connectionStatusProvider.isOnline else {
            return .failure(.internetConnectionOffline([self, #file, #function, #line]))
        }

        delegates.activityIndicator.show()
        firebaseAuth.languageCode = languageCode

        let formattedNumber = "+\(internationalNumber.digits)"
        do {
            let authID = try await phoneAuthProvider.verifyPhoneNumber(formattedNumber, uiDelegate: nil)
            delegates.activityIndicator.hide()
            return .success(authID)
        } catch {
            delegates.activityIndicator.hide()
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }
}
