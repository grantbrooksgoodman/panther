//
//  LegacyUserService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import CryptoKit
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

struct LegacyUserService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Methods

    /// Converts the user with the given `id` to the Panther database schema and removes references to old conversations.
    /// - Parameter id: The identifier of the user to be converted.
    /// - Warning: This method will clear all open conversations for the legacy user associated with the provided ID.
    func convertUser(
        id: String
    ) async throws(Exception) {
        let userInfo = ["UserID": id]
        let userPath = "\(NetworkPath.users.rawValue)/\(id)"
        var userData: [String: Any]

        do {
            userData = try await networking.database.getValues(
                at: userPath
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        userData[User.SerializableKey.id.rawValue] = id

        guard !User.canDecode(from: userData) else {
            throw Exception(
                "User does not need conversion to new schema.",
                isReportable: false,
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        guard let callingCode = userData["callingCode"] as? String,
              let nationalNumberString = userData["phoneNumber"] as? String,
              let regionCode = userData["region"] as? String else {
            throw Exception(
                "Failed to decode number information.",
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }

        let newDictionary = [
            "callingCode": callingCode,
            "nationalNumberString": nationalNumberString,
            "regionCode": regionCode,
        ]

        do {
            try await networking.database.setValue(
                NSNull(),
                forKey: "\(userPath)/\(User.SerializableKey.phoneNumber.rawValue)"
            )

            try await networking.database.setValue(
                newDictionary,
                forKey: "\(userPath)/\(User.SerializableKey.phoneNumber.rawValue)"
            )

            try await networking.database.setValue(
                NSNull(),
                forKey: "\(userPath)/callingCode"
            )

            try await networking.database.setValue(
                NSNull(),
                forKey: "\(userPath)/region"
            )

            try await networking.database.setValue(
                Array.bangQualifiedEmpty,
                forKey: "\(userPath)/\(User.SerializableKey.blockedUserIDs.rawValue)"
            )

            try await networking.database.setValue(
                Array.bangQualifiedEmpty,
                forKey: "\(userPath)/\(User.SerializableKey.conversationIDs.rawValue)"
            )
        } catch {
            throw error.appending(userInfo: userInfo)
        }

        Logger.log(
            "Successfully converted user with ID «\(id)» to new schema.",
            domain: .user,
            sender: self
        )
    }
}

private extension String {
    var legacyHash: String {
        let compressedData = try? (Data(utf8) as NSData).compressed(using: .lzfse)

        guard let data = compressedData else {
            return SHA256.hash(data: Data(utf8)).compactMap { String(format: "%02x", $0) }.joined()
        }

        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
