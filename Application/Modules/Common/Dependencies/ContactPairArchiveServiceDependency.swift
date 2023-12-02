//
//  ContactPairArchiveServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum ContactPairArchiveServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ContactPairArchiveService {
        .init()
    }
}

public extension DependencyValues {
    var contactPairArchiveService: ContactPairArchiveService {
        get { self[ContactPairArchiveServiceDependency.self] }
        set { self[ContactPairArchiveServiceDependency.self] = newValue }
    }
}
