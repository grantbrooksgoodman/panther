//
//  MetadataServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum MetadataServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> MetadataService {
        .init()
    }
}

public extension DependencyValues {
    var metadataService: MetadataService {
        get { self[MetadataServiceDependency.self] }
        set { self[MetadataServiceDependency.self] = newValue }
    }
}
