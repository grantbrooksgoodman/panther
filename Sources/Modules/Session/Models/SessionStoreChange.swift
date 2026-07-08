//
//  SessionStoreChange.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

enum SessionStoreChange: Equatable {
    case conversations(upsertedIDKeys: Set<String>, removedIDKeys: Set<String>)
    case messages(upsertedIDs: Set<String>)
    case users(upsertedIDs: Set<String>)
}
