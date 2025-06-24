//
//  ConnectionStatusServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct ConnectionStatusServiceEffectID: Hashable {
    // MARK: - Properties

    public let rawValue: String

    // MARK: - Init

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

public extension ConnectionStatusServiceEffectID {
    static let checkForUpdates: ConnectionStatusServiceEffectID = .init("checkForUpdates")
    static let configureInputBar: ConnectionStatusServiceEffectID = .init("configureInputBar")
    static let showOfflineModeToast: ConnectionStatusServiceEffectID = .init("showOfflineModeToast")
}
