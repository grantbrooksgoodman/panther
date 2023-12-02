//
//  ReviewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum ReviewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ReviewService {
        .init()
    }
}

public extension DependencyValues {
    var reviewService: ReviewService {
        get { self[ReviewServiceDependency.self] }
        set { self[ReviewServiceDependency.self] = newValue }
    }
}
