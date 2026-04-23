//
//  LockBox.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

final class LockBox<Value>: Sendable {
    // MARK: - Properties

    private let _value = LockIsolated<Value?>(wrappedValue: nil)

    // MARK: - Computed Properties

    var value: Value? {
        get { _value.wrappedValue }
        set { _value.wrappedValue = newValue }
    }
}
