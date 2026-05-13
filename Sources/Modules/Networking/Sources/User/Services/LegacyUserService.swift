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
    /// - Returns: An optional `Exception` describing the error encountered.
    /// - Warning: This method will clear all open conversations for the legacy user associated with the provided ID.
    func convertUser(id: String) async -> Exception? {
        let userInfo = ["UserID": id]
        let userPath = "\(NetworkPath.users.rawValue)/\(id)"
        var userData: [String: Any]

        do {
            userData = try await networking.database.getValues(
                at: userPath
            )
        } catch {
            return error.appending(userInfo: userInfo)
        }

        userData[User.SerializableKey.id.rawValue] = id

        guard !User.canDecode(from: userData) else {
            let exception = Exception(
                "User does not need conversion to new schema.",
                isReportable: false,
                metadata: .init(sender: self)
            )
            return exception.appending(userInfo: userInfo)
        }

        guard let callingCode = userData["callingCode"] as? String,
              let nationalNumberString = userData["phoneNumber"] as? String,
              let regionCode = userData["region"] as? String else {
            let exception = Exception("Failed to decode number information.", metadata: .init(sender: self))
            return exception.appending(userInfo: userInfo)
        }

        let newDictionary = [
            "callingCode": callingCode,
            "nationalNumberString": nationalNumberString,
            "regionCode": regionCode,
        ]

        if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/\(User.SerializableKey.phoneNumber.rawValue)") {
            return exception.appending(userInfo: userInfo)
        }

        if let exception = await networking.database.setValue(newDictionary, forKey: "\(userPath)/\(User.SerializableKey.phoneNumber.rawValue)") {
            return exception.appending(userInfo: userInfo)
        }

        if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/callingCode") {
            return exception.appending(userInfo: userInfo)
        }

        if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/region") {
            return exception.appending(userInfo: userInfo)
        }

        if let exception = await networking.database.setValue(
            Array.bangQualifiedEmpty,
            forKey: "\(userPath)/\(User.SerializableKey.blockedUserIDs.rawValue)"
        ) {
            return exception.appending(userInfo: userInfo)
        }

        if let exception = await networking.database.setValue(
            Array.bangQualifiedEmpty,
            forKey: "\(userPath)/\(User.SerializableKey.conversationIDs.rawValue)"
        ) {
            return exception.appending(userInfo: userInfo)
        }

        Logger.log(
            "Successfully converted user with ID «\(id)» to new schema.",
            domain: .user,
            sender: self
        )

        return nil
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
