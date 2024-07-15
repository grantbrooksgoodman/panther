//
//  Data+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 15/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Data {
    static func fromURL(_ url: URL) -> Callback<Data, Exception> {
        let commonParams = ["URLPath": url.path()]

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                return .failure(.init(
                    "Found empty data at path.",
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams))
            }

            return .success(data)
        } catch {
            return .failure(
                .init(
                    error,
                    metadata: [self, #file, #function, #line]
                ).appending(extraParams: commonParams)
            )
        }
    }
}
