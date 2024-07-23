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

/* 3rd-party */
import CoreArchitecture

public enum QLThumbnailGeneratorDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> QLThumbnailGenerator {
        .shared
    }
}

public extension DependencyValues {
    var qlThumbnailGenerator: QLThumbnailGenerator {
        get { self[QLThumbnailGeneratorDependency.self] }
        set { self[QLThumbnailGeneratorDependency.self] = newValue }
    }
}
