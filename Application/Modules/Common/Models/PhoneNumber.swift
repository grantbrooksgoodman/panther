//
//  PhoneNumber.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct PhoneNumber: Codable, CompressedHashable, Equatable {
    // MARK: - Properties

    public let callingCode: String
    public let internalFormattedString: String?
    public let label: String?
    public let nationalNumberString: String
    public let regionCode: String

    // MARK: - Computed Properties

    public var compiledNumberString: String { callingCode + nationalNumberString }
    public var hashFactors: [String] {
        [
            callingCode,
            internalFormattedString ?? "",
            label ?? "",
            nationalNumberString,
            regionCode,
        ]
    }

    // MARK: - Init

    public init(
        callingCode: String,
        nationalNumberString: String,
        regionCode: String,
        label: String?,
        internalFormattedString: String?
    ) {
        self.callingCode = callingCode.digits
        self.nationalNumberString = nationalNumberString.digits
        self.regionCode = regionCode
        self.label = label?.trimmingBorderedWhitespace.trimmingCharacters(in: .newlines)
        self.internalFormattedString = internalFormattedString
    }
}
