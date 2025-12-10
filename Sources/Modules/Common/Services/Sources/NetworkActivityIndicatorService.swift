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

    var backgroundColor: Color {
        Application.isInPrevaricationMode ? .init(uiColor: .systemBlue) : .accent
    }

    var progressViewTintColor: Color {
        ThemeService.isAppDefaultThemeApplied &&
            ThemeService.isDarkModeActive &&
            UIApplication.isFullyV26Compatible ? .black : .white
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
