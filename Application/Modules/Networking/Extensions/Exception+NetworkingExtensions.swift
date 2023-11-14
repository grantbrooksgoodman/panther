//
//  Exception+NetworkingExtensions.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Exception {
    init(_ error: Error?, metadata: [Any]) {
        guard let error else {
            self.init(metadata: metadata)
            return
        }

        self.init(error, metadata: metadata)
    }
}
