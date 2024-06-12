//
//  ChatPageViewControllerFactoryDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum ChatPageViewControllerFactoryDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ChatPageViewControllerFactory {
        .init()
    }
}

public extension DependencyValues {
    var chatPageViewControllerFactory: ChatPageViewControllerFactory {
        get { self[ChatPageViewControllerFactoryDependency.self] }
        set { self[ChatPageViewControllerFactoryDependency.self] = newValue }
    }
}
