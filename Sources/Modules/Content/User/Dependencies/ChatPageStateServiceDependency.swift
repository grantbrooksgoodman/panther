//
//  ChatPageStateServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public enum ChatPageStateServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> ChatPageStateService {
        .init(isPresented: false, isWaitingToUpdateConversations: false)
    }
}

public extension DependencyValues {
    var chatPageStateService: ChatPageStateService {
        get { self[ChatPageStateServiceDependency.self] }
        set { self[ChatPageStateServiceDependency.self] = newValue }
    }
}
