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

/// The delegate that styles and controls the network activity indicator.
///
/// The service forwards presentation to the framework's default indicator behavior and
/// notifies observers whenever network activity occurs.
struct NetworkActivityIndicatorService: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    private let defaultNetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()

    @SharedEvent(\.networkActivityOccurred) private var networkActivityOccurred

    // MARK: - Computed Properties

    /// The background color of the network activity indicator.
    var backgroundColor: Color? {
        defaultNetworkActivityIndicatorDelegate.backgroundColor
    }

    /// The tint color of the network activity indicator's progress view.
    var progressViewTintColor: Color? {
        if UIApplication.isFullyV26Compatible {
            ThemeService.isDarkModeActive ? .white : .black
        } else {
            .white
        }
    }

    // MARK: - Methods

    /// Hides the network activity indicator.
    func hide() {
        defaultNetworkActivityIndicatorDelegate.hide()
    }

    /// Shows the network activity indicator and notifies observers that network activity
    /// occurred.
    func show() {
        defaultNetworkActivityIndicatorDelegate.show()
        networkActivityOccurred.send()
    }
}
