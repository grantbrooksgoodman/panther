//
//  ConversationsPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum ConversationsPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ConversationsPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var conversationsPageViewService: ConversationsPageViewService {
        get { self[ConversationsPageViewServiceDependency.self] }
        set { self[ConversationsPageViewServiceDependency.self] = newValue }
    }
}
