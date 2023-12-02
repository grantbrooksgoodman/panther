//
//  UserInteractiveQOSQueueDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum UserInteractiveQOSQueueDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> DispatchQueue {
        .global(qos: .userInteractive)
    }
}

public extension DependencyValues {
    var userInteractiveQOSQueue: DispatchQueue {
        get { self[UserInteractiveQOSQueueDependency.self] }
        set { self[UserInteractiveQOSQueueDependency.self] = newValue }
    }
}
