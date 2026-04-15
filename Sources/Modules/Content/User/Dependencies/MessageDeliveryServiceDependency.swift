//
//  MessageDeliveryServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum MessageDeliveryServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> MessageDeliveryService {
        @MainActorIsolated var messageDeliveryService = MessageDeliveryService()
        return messageDeliveryService
    }
}

extension DependencyValues {
    var messageDeliveryService: MessageDeliveryService {
        get { self[MessageDeliveryServiceDependency.self] }
        set { self[MessageDeliveryServiceDependency.self] = newValue }
    }
}
