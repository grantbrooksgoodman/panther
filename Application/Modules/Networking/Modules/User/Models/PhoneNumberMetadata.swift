//
//  PhoneNumberMetadata.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct PhoneNumberMetadata: Codable, Equatable {
    // MARK: - Properties

    public let callingCode: String
    public let nationalNumberString: String
    public let regionCode: String

    // MARK: - Init

    public init(
        _ nationalNumberString: String,
        callingCode: String,
        regionCode: String
    ) {
        self.nationalNumberString = nationalNumberString
        self.callingCode = callingCode
        self.regionCode = regionCode
    }
}
