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

public struct NetworkActivityIndicatorService: NetworkActivityIndicatorDelegate {
    // MARK: - Properties

    private let defaultNetworkActivityIndicatorDelegate = DefaultNetworkActivityIndicatorDelegate()

    // MARK: - Computed Properties

    public var backgroundColor: Color {
        Application.isInPrevaricationMode ? .init(uiColor: .systemBlue) : .accent
    }

    public var progressViewTintColor: Color {
        ThemeService.isAppDefaultThemeApplied &&
            ThemeService.isDarkModeActive &&
            UIApplication.v26FeaturesEnabled ? .black : .white
    }

    // MARK: - Methods

    public func hide() {
        defaultNetworkActivityIndicatorDelegate.hide()
    }

    public func show() {
        defaultNetworkActivityIndicatorDelegate.show()
        Observables.networkActivityOccurred.trigger()
    }
}
