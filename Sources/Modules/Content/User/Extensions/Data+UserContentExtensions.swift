//
//  Data+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

extension Data {
    /// Returns the data at the given URL.
    ///
    /// - Parameter url: The URL to read.
    ///
    /// - Returns: The data at the URL.
    ///
    /// - Throws: An `Exception` if the URL cannot be read or contains no data.
    static func fromURL(_ url: URL) throws(Exception) -> Data {
        let userInfo = ["URLPath": url.path()]

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                throw Exception(
                    "Found empty data at path.",
                    metadata: .init(sender: self)
                ).appending(userInfo: userInfo)
            }

            return data
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            ).appending(userInfo: userInfo)
        }
    }
}
