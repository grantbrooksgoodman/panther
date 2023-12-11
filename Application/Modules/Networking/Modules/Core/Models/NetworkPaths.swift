//
//  NetworkPaths.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkPaths {
    // MARK: - Type Aliases

    private typealias Path = NetworkPath

    // MARK: - Types

    private enum NetworkPath: String {
        case conversations
        case messages
        case shared
        case translations
        case userHashes
        case users
    }

    // MARK: - Properties

    public let conversations = Path.conversations.rawValue
    public let messages = Path.messages.rawValue
    public let shared = Path.shared.rawValue
    public let translations = Path.translations.rawValue
    public let userHashes = Path.userHashes.rawValue
    public let users = Path.users.rawValue
}
