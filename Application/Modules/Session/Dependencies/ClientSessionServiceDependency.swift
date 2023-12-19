//
//  ClientSessionServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum ClientSessionServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ClientSessionService {
        .init(
            conversation: .init(),
            message: .init(),
            user: .init()
        )
    }
}

public extension DependencyValues {
    var clientSessionService: ClientSessionService {
        get { self[ClientSessionServiceDependency.self] }
        set { self[ClientSessionServiceDependency.self] = newValue }
    }
}
