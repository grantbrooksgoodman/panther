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

    @Dependency(\.firebaseAuth) private var firebaseAuth: FirebaseAuth.Auth
    @Dependency(\.networking.activityIndicator) private var networkActivity: NetworkActivityIndicator
    @Dependency(\.firebasePhoneAuthProvider) private var phoneAuthProvider: PhoneAuthProvider

    // MARK: - Authentication with Verification Code

    /// - Returns: On success, a string representing the user's ID.
    public func authenticateUser(
        authID: String,
        verificationCode: String
    ) async -> Callback<String, Exception> {
        networkActivity.show()

        let credential = phoneAuthProvider.credential(withVerificationID: authID, verificationCode: verificationCode)

        do {
            let signInResult = try await firebaseAuth.signIn(with: credential)
            networkActivity.hide()
            return .success(signInResult.user.uid)
        } catch {
            networkActivity.hide()
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Phone Number Verification

    /// - Returns: On success, a string representing the phone number verification ID.
    public func verifyPhoneNumber(
        internationalNumber: String,
        languageCode: String = RuntimeStorage.languageCode
    ) async -> Callback<String, Exception> {
        networkActivity.show()
        firebaseAuth.languageCode = languageCode

        let formattedNumber = "+\(internationalNumber.digits)"
        do {
            let authID = try await phoneAuthProvider.verifyPhoneNumber(formattedNumber, uiDelegate: nil)
            networkActivity.hide()
            return .success(authID)
        } catch {
            networkActivity.hide()
            return .failure(.init(error, metadata: [self, #file, #function, #line]))
        }
    }
}
