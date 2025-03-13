//
//  Logger+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

public extension Logger.AlertType {
    static var toastInPrerelease: Logger.AlertType? {
        @Dependency(\.build) var build: Build
        guard build.milestone != .generalRelease else { return nil }
        return .toast()
    }
}
