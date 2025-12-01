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

enum InviteQRCodePageViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> InviteQRCodePageViewService {
        .init()
    }
}

extension DependencyValues {
    var inviteQRCodePageViewService: InviteQRCodePageViewService {
        get { self[InviteQRCodePageViewServiceDependency.self] }
        set { self[InviteQRCodePageViewServiceDependency.self] = newValue }
    }
}
