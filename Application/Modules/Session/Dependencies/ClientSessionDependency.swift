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
import Redux

public enum ClientSessionDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ClientSession {
        @Dependency(\.chatPageViewService.deliveryProgression) var deliveryProgressionService: DeliveryProgressionService?
        return .init(
            conversation: .init(),
            deliveryProgressIndicator: deliveryProgressionService,
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
