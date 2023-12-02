//
//  String+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import PhoneNumberKit
import Redux

public extension String {
    // MARK: - Properties

    var isBlank: Bool {
        lowercasedTrimmingWhitespace == ""
    }

    var phoneNumberFormatted: String {
        @Dependency(\.phoneNumberService) var phoneNumberService: PhoneNumberService
        guard digits != "" else { return self }
        return phoneNumberService.format(self)
    }

    // MARK: - Methods

    func partiallyFormatted(for region: String) -> String {
        @Dependency(\.phoneNumberService) var phoneNumberService: PhoneNumberService
        @Dependency(\.regionDetailService) var regionDetailService: RegionDetailService

        guard digits != "" else { return self }

        var fullFormatAttempt = phoneNumberService.format(self)
        guard let callingCode = regionDetailService.callingCode(regionCode: region) else { return fullFormatAttempt }

        guard fullFormatAttempt == phoneNumberService.failsafeFormat(self) else {
            guard fullFormatAttempt.hasPrefix("+\(callingCode)") else {
                let partialFormatter = PartialFormatter(defaultRegion: region.uppercased(), withPrefix: true)
                return partialFormatter.formatPartial(digits)
            }

            fullFormatAttempt = fullFormatAttempt.removingOccurrences(of: ["+"])
            fullFormatAttempt = fullFormatAttempt.dropPrefix(callingCode.count)

            return fullFormatAttempt.trimmingBorderedWhitespace
        }

        let partialFormatter = PartialFormatter(defaultRegion: region.uppercased(), withPrefix: true)
        return partialFormatter.formatPartial(digits)
    }
}
