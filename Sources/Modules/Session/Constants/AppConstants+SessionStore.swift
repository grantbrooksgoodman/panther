//
//  AppConstants+SessionStore.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

// MARK: - CGFloat

extension AppConstants.CGFloats {
    enum SessionStore { // NIT: Technically using Int here.
        /// The maximum number of messages persisted per
        /// conversation. In-memory state retains all
        /// messages for the session; this cap applies
        /// only to the on-disk archive snapshot.
        static let messageArchiveCapPerConversation: Int = 500
    }
}
