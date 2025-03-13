//
//  InviteQRCodePageViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/07/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum InviteQRCodePageViewServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> InviteQRCodePageViewService {
        .init()
    }
}

public extension DependencyValues {
    var inviteQRCodePageViewService: InviteQRCodePageViewService {
        get { self[InviteQRCodePageViewServiceDependency.self] }
        set { self[InviteQRCodePageViewServiceDependency.self] = newValue }
    }
}
