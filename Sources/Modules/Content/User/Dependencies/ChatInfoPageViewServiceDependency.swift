//
//  ChatInfoPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ChatInfoPageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ChatInfoPageViewService {
        .init()
    }
}

extension DependencyValues {
    var chatInfoPageViewService: ChatInfoPageViewService {
        get { self[ChatInfoPageViewServiceDependency.self] }
        set { self[ChatInfoPageViewServiceDependency.self] = newValue }
    }
}
