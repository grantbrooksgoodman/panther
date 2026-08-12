//
//  ConnectionStatusServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// A unique identifier for an effect registered with ``ConnectionStatusService``.
struct ConnectionStatusServiceEffectID: Hashable {
    // MARK: - Properties

    /// The string that identifies the effect.
    let rawValue: String

    // MARK: - Init

    /// Creates an identifier with the given string.
    ///
    /// - Parameter rawValue: The string that identifies the effect.
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ConnectionStatusServiceEffectID {
    static let checkForUpdates: ConnectionStatusServiceEffectID = .init("checkForUpdates")
    static let configureInputBar: ConnectionStatusServiceEffectID = .init("configureInputBar")
    static let retryMessageOutbox: ConnectionStatusServiceEffectID = .init("retryMessageOutbox")
    static let showOfflineModeToast: ConnectionStatusServiceEffectID = .init("showOfflineModeToast")
}
