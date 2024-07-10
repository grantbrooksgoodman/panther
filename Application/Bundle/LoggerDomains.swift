//
//  LoggerDomains.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum LoggerDomain: String, CaseIterable {
    /* Add cases here to expose new domains to the logger. */

    case alertKit
    case general
    case bugPrevention
    case chatPageState
    case contacts
    case conversation
    case database
    case dataIntegrity
    case hostedTranslation
    case notifications
    case observer
    case queue
    case storage
    case translation
    case user
    case userSession
}
