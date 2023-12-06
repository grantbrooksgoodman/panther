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
        lowercasedTrimmingWhitespaceAndNewlines.isEmpty
    }

    var phoneNumberFormatted: String {
        @Dependency(\.commonServices.phoneNumber) var phoneNumberService: PhoneNumberService
        guard digits != "" else { return self }
        return phoneNumberService.format(self)
    }

    // MARK: - Methods

    func partiallyFormatted(for region: String) -> String {
        @Dependency(\.commonServices) var services: CommonServices

        guard digits != "" else { return self }

        var fullFormatAttempt = services.phoneNumber.format(self)
        guard let callingCode = services.regionDetail.callingCode(regionCode: region) else { return fullFormatAttempt }

        guard fullFormatAttempt == services.phoneNumber.failsafeFormat(self) else {
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
