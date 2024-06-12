//
//  MessageDeliveryServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 04/04/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public enum MessageDeliveryServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> MessageDeliveryService {
        .init()
    }
}

public extension DependencyValues {
    var messageDeliveryService: MessageDeliveryService {
        get { self[MessageDeliveryServiceDependency.self] }
        set { self[MessageDeliveryServiceDependency.self] = newValue }
    }
}
