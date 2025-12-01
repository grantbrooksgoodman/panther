//
//  ConversationCellViewServiceDependency.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 23/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

enum ConversationCellViewServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> ConversationCellViewService {
        .init()
    }
}

extension DependencyValues {
    var conversationCellViewService: ConversationCellViewService {
        get { self[ConversationCellViewServiceDependency.self] }
        set { self[ConversationCellViewServiceDependency.self] = newValue }
    }
}
