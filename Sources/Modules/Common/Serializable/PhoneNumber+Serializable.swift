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

    typealias T = PhoneNumber
    private typealias Keys = SerializableKey

    // MARK: - Types

    private enum SerializableKey: String {
        case callingCode
        case nationalNumberString
        case regionCode
    }

    // MARK: - Properties

    var encoded: [String: Any] {
        [
            Keys.callingCode.rawValue: callingCode,
            Keys.nationalNumberString.rawValue: nationalNumberString,
            Keys.regionCode.rawValue: regionCode,
        ]
    }

    // MARK: - Init

    convenience init(
        from data: [String: Any]
    ) async throws(Exception) {
        guard let callingCode = data[Keys.callingCode.rawValue] as? String,
              let nationalNumberString = data[Keys.nationalNumberString.rawValue] as? String,
              let regionCode = data[Keys.regionCode.rawValue] as? String else {
            throw .Networking.decodingFailed(
                data: data,
                .init(sender: Self.self)
            )
        }

        self.init(
            callingCode: callingCode,
            nationalNumberString: nationalNumberString,
            regionCode: regionCode,
            label: nil,
            internalFormattedString: nil
        )
    }

    // MARK: - Methods

    static func canDecode(
        from data: [String: Any]
    ) -> Bool {
        guard (data[Keys.callingCode.rawValue] as? String)?.digits.isBlank == false,
              (data[Keys.nationalNumberString.rawValue] as? String)?.digits.isBlank == false,
              data[Keys.regionCode.rawValue] is String else { return false }

        return true
    }
}
