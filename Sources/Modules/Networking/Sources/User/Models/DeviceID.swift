//
//  DeviceID.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/// A namespace for the current device's persistent identifier.
enum DeviceID {
    // MARK: - Properties

    private static let account = "us.neotechnica.deviceID"

    // MARK: - Computed Properties

    /// The current device's identifier.
    ///
    /// The identifier is generated on first access – from the device's vendor identifier, or a
    /// new UUID when unavailable – and persisted to the keychain so it survives reinstalls.
    static var current: String {
        get async {
            if let existingID = read(),
               existingID.hasPrefix("ios_") {
                return existingID
            }

            let newID = await "ios_\((MainActor.run { UIDevice.current.identifierForVendor } ?? UUID()).uuidString)"
            save(newID)
            return newID
        }
    }

    // MARK: - Methods

    /// Removes the current device's persisted identifier.
    ///
    /// The next access to ``current`` generates and persists a new identifier, exactly as on first
    /// access.
    ///
    /// - Important: This method doesn't update the current user's remote record. Call
    ///   ``User/updateDeviceIDIfNeeded()`` afterward to bring the record in line; otherwise, the
    ///   mismatch can sign the user out to preserve a single active session.
    ///
    /// - Note: Because the new identifier derives from the device's vendor identifier when
    ///   available, it can match the identifier it replaces.
    static func reset() {
        let query: [CFString: Any] = [
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Auxiliary

    private static func read() -> String? {
        let query: [CFString: Any] = [
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(
            data: data,
            encoding: .utf8
        )
    }

    private static func save(_ value: String) {
        let query: [CFString: Any] = [
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecValueData: Data(value.utf8),
        ]

        SecItemAdd(
            query as CFDictionary,
            nil
        )
    }
}
