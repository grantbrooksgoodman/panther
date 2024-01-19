//
//  Exception+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension Exception {
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
