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

public struct LegacyUserService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Methods

    /// Converts the user with the given `id` to the Panther database schema and removes references to old conversations.
    /// - Parameter id: The identifier of the user to be converted.
    /// - Returns: An optional `Exception` describing the error encountered.
    /// - Warning: This method will clear all open conversations for the legacy user associated with the provided ID.
    public func convertUser(id: String) async -> Exception? {
        let commonParams = ["UserID": id]

        let userPath = "\(networking.config.paths.users)/\(id)"
        let getValuesResult = await networking.database.getValues(at: userPath)

        switch getValuesResult {
        case let .success(values):
            guard var dictionary = values as? [String: Any] else {
                let exception: Exception = .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            dictionary[User.SerializationKeys.id.rawValue] = id

            guard !User.canDecode(from: dictionary) else {
                let exception = Exception("User does not need conversion to new schema.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            guard let callingCode = dictionary["callingCode"] as? String,
                  let nationalNumberString = dictionary["phoneNumber"] as? String,
                  let regionCode = dictionary["region"] as? String else {
                let exception = Exception("Failed to decode number information.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            let newDictionary = [
                "callingCode": callingCode,
                "nationalNumberString": nationalNumberString,
                "regionCode": regionCode,
            ]

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/\(User.SerializationKeys.phoneNumber.rawValue)") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(newDictionary, forKey: "\(userPath)/\(User.SerializationKeys.phoneNumber.rawValue)") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/callingCode") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/region") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(
                Array.bangQualifiedEmpty,
                forKey: "\(userPath)/\(User.SerializationKeys.blockedUserIDs.rawValue)"
            ) {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(
                Array.bangQualifiedEmpty,
                forKey: "\(userPath)/\(User.SerializationKeys.conversationIDs.rawValue)"
            ) {
                return exception.appending(extraParams: commonParams)
            }

            let legacyHashPath = "userHashes/\(nationalNumberString.legacyHash)"
            let getValuesResult = await networking.database.getValues(at: legacyHashPath)

            switch getValuesResult {
            case let .success(values):
                guard var array = values as? [String] else {
                    let exception: Exception = .typecastFailed("array", metadata: [self, #file, #function, #line])
                    return exception.appending(extraParams: commonParams)
                }

                array = array.filter { $0 != id }

                if let exception = await networking.database.setValue(array, forKey: legacyHashPath) {
                    return exception.appending(extraParams: commonParams)
                }

                let newHash = nationalNumberString.encodedHash
                let newHashPath = "\(networking.config.paths.userNumberHashes)/\(newHash)"
                let getValuesResult = await networking.database.getValues(at: newHashPath)

                switch getValuesResult {
                case let .success(values):
                    guard var array = values as? [String] else {
                        let exception: Exception = .typecastFailed("array", metadata: [self, #file, #function, #line])
                        return exception.appending(extraParams: commonParams)
                    }

                    array.append(id)
                    array = array.unique

                    if let exception = await networking.database.setValue(array, forKey: newHashPath) {
                        return exception.appending(extraParams: commonParams)
                    }

                    Logger.log(
                        "Successfully converted user with ID «\(id)» to new schema.",
                        domain: .user,
                        metadata: [self, #file, #function, #line]
                    )

                case let .failure(exception):
                    guard exception.isEqual(to: .noValueExists) else {
                        return exception.appending(extraParams: commonParams)
                    }

                    if let exception = await networking.database.setValue([id], forKey: newHashPath) {
                        return exception.appending(extraParams: commonParams)
                    }

                    Logger.log(
                        "Successfully converted user with ID «\(id)» to new schema.",
                        domain: .user,
                        metadata: [self, #file, #function, #line]
                    )
                }

            case let .failure(exception):
                return exception.appending(extraParams: commonParams)
            }

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }

        return nil
    }

    public func renameNumberData(forUser id: String) async -> Exception? {
        let commonParams = ["UserID": id]

        let userPath = "\(networking.config.paths.users)/\(id)"
        let getValuesResult = await networking.database.getValues(at: userPath)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                let exception: Exception = .typecastFailed("dictionary", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            guard let numberData = dictionary["numberData"] as? [String: Any] else {
                let exception = Exception("Failed to decode number information.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/numberData") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(numberData, forKey: "\(userPath)/\(User.SerializationKeys.phoneNumber.rawValue)") {
                return exception.appending(extraParams: commonParams)
            }

            Logger.log(
                "Successfully renamed number data for user with ID «\(id)».",
                domain: .user,
                metadata: [self, #file, #function, #line]
            )

        case let .failure(exception):
            return exception.appending(extraParams: commonParams)
        }

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
