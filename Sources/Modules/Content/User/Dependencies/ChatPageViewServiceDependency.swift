//
//  ChatPageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 31/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ChatPageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ChatPageViewService {
        // swiftformat:disable all
        @MainActorIsolated var chatPageViewService = ChatPageViewService()
        return chatPageViewService // swiftformat:enable all
    }
}

extension DependencyValues {
    var chatPageViewService: ChatPageViewService {
        get { self[ChatPageViewServiceDependency.self] }
        set { self[ChatPageViewServiceDependency.self] = newValue }
    }
}
