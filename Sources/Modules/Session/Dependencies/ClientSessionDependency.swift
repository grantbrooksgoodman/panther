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

enum ClientSessionDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ClientSession {
        .init(
            activity: .init(),
            conversation: .init(),
            message: .init(),
            moderation: .init(),
            reaction: .init(),
            storage: .init(),
            user: .init()
        )
    }
}

extension DependencyValues {
    var clientSession: ClientSession {
        get { self[ClientSessionDependency.self] }
        set { self[ClientSessionDependency.self] = newValue }
    }
}
