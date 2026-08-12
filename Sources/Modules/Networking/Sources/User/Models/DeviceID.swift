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

/* Proprietary */
import AppSubsystem

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
        if let existingID = read() { return existingID }
        @MainActorIsolated var vendorID = UIDevice.current.identifierForVendor
        let newID = (vendorID ?? UUID()).uuidString
        save(newID)
        return newID
    }

    // MARK: - Methods

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
