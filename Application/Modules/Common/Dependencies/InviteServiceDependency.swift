//
//  InviteServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

public enum InviteServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> InviteService {
        .init()
    }
}

public extension DependencyValues {
    var inviteService: InviteService {
        get { self[InviteServiceDependency.self] }
        set { self[InviteServiceDependency.self] = newValue }
    }
}
