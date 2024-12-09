//
//  NetworkPaths.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import Networking

public extension NetworkPath {
    static let audioMessageInputs: NetworkPath = .init("audioMessageInputs")
    static let audioTranslations: NetworkPath = .init("audioTranslations")
    static let conversations: NetworkPath = .init("conversations")
    static let deletedUsers: NetworkPath = .init("deletedUsers")
    static let invalidatedCaches: NetworkPath = .init("invalidatedCaches")
    static let media: NetworkPath = .init("media")
    static let messages: NetworkPath = .init("messages")
    static let reportedUsers: NetworkPath = .init("reportedUsers")
    static let shared: NetworkPath = .init("shared")
    static let translations: NetworkPath = .init("translations")
    static let users: NetworkPath = .init("users")
}
