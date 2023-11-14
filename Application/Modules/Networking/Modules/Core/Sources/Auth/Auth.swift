//
//  Auth.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 11/9/23.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import FirebaseAuth
import Redux

public struct Auth {
    // MARK: - Dependencies

    @Dependency(\.firebaseAuth) private var firebaseAuth: FirebaseAuth.Auth
    @Dependency(\.firebasePhoneAuthProvider) private var phoneAuthProvider: PhoneAuthProvider

    // MARK: - Authentication with Verification Code

    /// - Returns: On success, a string representing the user's ID.
    public func authenticateUser(
        authID: String,
        verificationCode: String
    ) async -> Callback<String, Exception> {
        let credential = phoneAuthProvider.credential(withVerificationID: authID, verificationCode: verificationCode)

        do {
            let signInResult = try await firebaseAuth.signIn(with: credential)
            return .success(signInResult.user.uid)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Phone Number Verification

    /// - Returns: On success, a string representing the phone number verification ID.
    public func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String = RuntimeStorage.languageCode
    ) async -> Callback<String, Exception> {
        firebaseAuth.languageCode = languageCode

        let formattedNumber = "+\(internationalNumber.digits)"
        do {
            let authID = try await phoneAuthProvider.verifyPhoneNumber(formattedNumber, uiDelegate: nil)
            return .success(authID)
        } catch {
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }
}
