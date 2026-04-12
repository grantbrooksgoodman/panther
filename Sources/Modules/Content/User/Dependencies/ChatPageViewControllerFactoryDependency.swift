//
//  ChatPageViewControllerFactoryDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ChatPageViewControllerFactoryDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ChatPageViewControllerFactory {
        @MainActorIsolated var chatPageViewControllerFactory = ChatPageViewControllerFactory()
        return chatPageViewControllerFactory
    }
}

extension DependencyValues {
    var chatPageViewControllerFactory: ChatPageViewControllerFactory {
        get { self[ChatPageViewControllerFactoryDependency.self] }
        set { self[ChatPageViewControllerFactoryDependency.self] = newValue }
    }
}
