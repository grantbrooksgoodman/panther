//
//  Exception+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
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

    static func invalidType(
        value: Any,
        _ metadata: [Any]
    ) -> Exception {
        .init(
            "Serialized type values must conform to NSArray, NSDictionary, NSNull, NSNumber, or NSString.",
            extraParams: ["Value": value],
            metadata: metadata
        )
    }
}
