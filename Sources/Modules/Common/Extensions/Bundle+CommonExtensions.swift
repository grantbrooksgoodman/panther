//
//  Bundle+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/06/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

extension Bundle {
    var containsStagingAssets: Bool {
        let requiredResources = [
            "audio": "m4a",
            "audio2": "m4a",
            "image": "jpeg",
            "image2": "jpeg",
            "video": "mp4",
        ]

        for resource in requiredResources {
            guard url(
                forResource: resource.key,
                withExtension: resource.value
            ) != nil else { return false }
        }

        return true
    }
}
