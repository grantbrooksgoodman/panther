//
//  Exception+CommonNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Exception {
    static func typecastFailed(
        _ typeName: String? = nil,
        extraParams: [String: Any]? = nil,
        metadata: [Any]
    ) -> Exception {
        .init(
            "Failed to typecast values \(typeName == nil ? "." : "to \(typeName!).")",
            extraParams: extraParams,
            metadata: metadata
        )
    }
}
