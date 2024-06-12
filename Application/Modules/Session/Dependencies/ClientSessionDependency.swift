//
//  ClientSessionDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum ClientSessionDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ClientSession {
        .init(
            conversation: .init(),
            message: .init(),
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
