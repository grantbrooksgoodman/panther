//
//  ConnectionStatusServiceEffectID.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 14/06/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

struct ConnectionStatusServiceEffectID: Hashable {
    // MARK: - Properties

    let rawValue: String

    // MARK: - Init

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ConnectionStatusServiceEffectID {
    static let checkForUpdates: ConnectionStatusServiceEffectID = .init("checkForUpdates")
    static let configureInputBar: ConnectionStatusServiceEffectID = .init("configureInputBar")
    static let showOfflineModeToast: ConnectionStatusServiceEffectID = .init("showOfflineModeToast")
}
