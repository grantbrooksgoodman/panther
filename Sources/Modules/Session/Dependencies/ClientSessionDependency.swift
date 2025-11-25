//
//  ClientSessionDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum ClientSessionDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ClientSession {
        .init(
            activity: .init(),
            conversation: .init(),
            message: .init(),
            moderation: .init(),
            reaction: .init(),
            user: .init()
        )
    }
}

public extension DependencyValues {
    var clientSession: ClientSession {
        get { self[ClientSessionDependency.self] }
        set { self[ClientSessionDependency.self] = newValue }
    }
}
