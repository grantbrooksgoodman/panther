//
//  ChatPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum ChatPageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ChatPageViewService {
        .init()
    }
}

public extension DependencyValues {
    var chatPageViewService: ChatPageViewService {
        get { self[ChatPageViewServiceDependency.self] }
        set { self[ChatPageViewServiceDependency.self] = newValue }
    }
}
