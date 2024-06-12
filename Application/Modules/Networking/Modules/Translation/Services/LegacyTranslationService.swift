//
//  LegacyTranslationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct LegacyTranslationService {
    // MARK: - Dependencies

    @Dependency(\.networking) private var networking: Networking

    // MARK: - Methods

    /// - Returns: On success, the new hash for the translation.
    public func regenerateHash(translationReferenceString: String) async -> Callback<String, Exception> {
        let path = networking.config.paths.translations
        let getValuesResult = await networking.database.getValues(at: "\(path)/\(translationReferenceString)")

        switch getValuesResult {
        case let .success(values):
            guard let string = values as? String else {
                return .failure(.init(
                    "Failed to typecast values to string.",
                    metadata: [self, #file, #function, #line]
                ))
            }

            let components = string.components(separatedBy: "–")
            guard components.count == 2,
                  let inputString = components[0].removingPercentEncoding else {
                return .failure(.init("Failed to decode translation reference.", metadata: [self, #file, #function, #line]))
            }

            if let exception = await networking.database.setValue(
                string,
                forKey: "\(path)/\(inputString.encodedHash)"
            ) {
                return .failure(exception)
            }

            if let exception = await networking.database.setValue(
                NSNull(),
                forKey: "\(path)/\(translationReferenceString)"
            ) {
                return .failure(exception)
            }

            return .success(inputString.encodedHash)

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
