//
//  PhoneNumber+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Networking

extension PhoneNumber: Serializable {
    // MARK: - Type Aliases

    public typealias T = PhoneNumber
    private typealias Keys = SerializationKeys

    // MARK: - Types

    private enum SerializationKeys: String {
        case callingCode
        case nationalNumberString
        case regionCode
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        [
            Keys.callingCode.rawValue: callingCode,
            Keys.nationalNumberString.rawValue: nationalNumberString,
            Keys.regionCode.rawValue: regionCode,
        ]
    }

    // MARK: - Methods

    public static func canDecode(from data: [String: Any]) -> Bool {
        guard data[Keys.callingCode.rawValue] as? String != nil,
              data[Keys.nationalNumberString.rawValue] as? String != nil,
              data[Keys.regionCode.rawValue] as? String != nil else { return false }

        return true
    }

    public static func decode(from data: [String: Any]) async -> Callback<PhoneNumber, Exception> {
        guard let callingCode = data[Keys.callingCode.rawValue] as? String,
              let nationalNumberString = data[Keys.nationalNumberString.rawValue] as? String,
              let regionCode = data[Keys.regionCode.rawValue] as? String else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let decoded: PhoneNumber = .init(
            callingCode: callingCode,
            nationalNumberString: nationalNumberString,
            regionCode: regionCode,
            label: nil,
            internalFormattedString: nil
        )

        return .success(decoded)
    }
}
