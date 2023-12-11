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

/* 3rd-party */
import Redux

public struct LegacyUserService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Methods

    public func convertUser(id: String) async -> Exception? {
        let commonParams = ["UserID": id]

        let userPath = "users/\(id)"
        let getValuesResult = await networking.database.getValues(at: userPath)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
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

            if let exception = await networking.database.setValue(newDictionary, forKey: "\(userPath)/phoneNumber") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/callingCode") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/phoneNumber") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/region") {
                return exception.appending(extraParams: commonParams)
            }

            let legacyHashPath = "userHashes/\(nationalNumberString.legacyHash)"
            let getValuesResult = await networking.database.getValues(at: legacyHashPath)

            switch getValuesResult {
            case let .success(values):
                guard var array = values as? [String] else {
                    let exception = Exception("Failed to typecast values to array.", metadata: [self, #file, #function, #line])
                    return exception.appending(extraParams: commonParams)
                }

                array = array.filter { $0 != id }

                if let exception = await networking.database.setValue(array, forKey: legacyHashPath) {
                    return exception.appending(extraParams: commonParams)
                }

                let newHash = nationalNumberString.compressedHash
                let newHashPath = "userHashes/\(newHash)"
                let getValuesResult = await networking.database.getValues(at: newHashPath)

                switch getValuesResult {
                case let .success(values):
                    guard var array = values as? [String] else {
                        let exception = Exception("Failed to typecast values to array.", metadata: [self, #file, #function, #line])
                        return exception.appending(extraParams: commonParams)
                    }

                    array.append(id)
                    array = array.unique

                    if let exception = await networking.database.setValue(array, forKey: newHashPath) {
                        return exception.appending(extraParams: commonParams)
                    }

                    Logger.log(
                        "Successfully converted user with ID «\(id)» to new schema.",
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

        let userPath = "users/\(id)"
        let getValuesResult = await networking.database.getValues(at: userPath)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else {
                let exception = Exception("Failed to typecast values to dictionary.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            guard let numberData = dictionary["numberData"] as? [String: Any] else {
                let exception = Exception("Failed to decode number information.", metadata: [self, #file, #function, #line])
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(NSNull(), forKey: "\(userPath)/numberData") {
                return exception.appending(extraParams: commonParams)
            }

            if let exception = await networking.database.setValue(numberData, forKey: "\(userPath)/phoneNumber") {
                return exception.appending(extraParams: commonParams)
            }

            Logger.log(
                "Successfully renamed number data for user with ID «\(id)».",
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
