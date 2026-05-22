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
