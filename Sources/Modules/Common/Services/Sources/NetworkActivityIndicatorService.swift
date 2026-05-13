//
//  NetworkActivityIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking

struct NetworkActivityIndicatorService: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    private let defaultNetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()

    // MARK: - Computed Properties

    var backgroundColor: Color? {
        nil
    }

    var progressViewTintColor: Color? {
        if UIApplication.isFullyV26Compatible {
            ThemeService.isDarkModeActive ? .white : .black
        } else {
            .white
        }
    }

    // MARK: - Methods

    func hide() {
        defaultNetworkActivityIndicatorDelegate.hide()
    }

    func show() {
        defaultNetworkActivityIndicatorDelegate.show()
        Observables.networkActivityOccurred.trigger()
    }
}
