//
//  ConnectionStatusProviderProtocol.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public protocol ConnectionStatusProvider {
    var isOnline: Bool { get }
}

public struct DefaultConnectionStatusProvider: ConnectionStatusProvider {
    public var isOnline = true
}
