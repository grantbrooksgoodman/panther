//
//  NetworkActivityIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public struct NetworkActivityIndicatorService: NetworkActivityIndicator {
    public func hide() {
        Observables.isNetworkActivityOccurring.value = false
    }

    public func show() {
        Observables.isNetworkActivityOccurring.value = true
        Observables.networkActivityOccurred.trigger()
    }
}
