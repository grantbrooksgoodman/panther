//
//  QLThumbnailGeneratorDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import QuickLook

/* Proprietary */
import AppSubsystem

enum QLThumbnailGeneratorDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> QLThumbnailGenerator {
        .shared
    }
}

extension DependencyValues {
    var qlThumbnailGenerator: QLThumbnailGenerator {
        get { self[QLThumbnailGeneratorDependency.self] }
        set { self[QLThumbnailGeneratorDependency.self] = newValue }
    }
}
