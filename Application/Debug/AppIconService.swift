//
//  AppIconService.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

public final class AppIconService {
    // MARK: - Types

    public enum AppIcon: String, CaseIterable {
        case blue = "Blue"
        case gray = "Application"
    }

    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.uiApplication) private var uiApplication: UIApplication

    // MARK: - Properties

    public private(set) var lastIconSet: AppIcon?

    private var alertDismissalTimer: Timer?

    // MARK: - Set App Icon

    public func setAppIcon(_ icon: AppIcon) {
        lastIconSet = icon
        uiApplication.setAlternateIconName("\(icon.rawValue) Icon") { error in
            guard let error else { return }
            Logger.log(.init(error, metadata: [self, #file, #function, #line]))
        }
    }

    // MARK: - Timer Methods

    public func startDismissingAlerts() {
        alertDismissalTimer = Timer.scheduledTimer(
            timeInterval: 0.01,
            target: self,
            selector: #selector(dismissAlerts),
            userInfo: nil,
            repeats: true
        )
    }

    public func stopDismissingAlerts() {
        alertDismissalTimer?.invalidate()
        alertDismissalTimer = nil
    }

    // MARK: - Dismiss Alerts

    @objc
    private func dismissAlerts() {
        guard let alertDismissalTimer,
              alertDismissalTimer.isValid else {
            Logger.log("Trying to call but timer is invalid!", metadata: [self, #file, #function, #line])
            return
        }

        core.ui.dismissAlertController()
    }

    // MARK: - Randomize App Icon

    public func randomizeAppIcon() {
        var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 2 == 0 }
        guard randomBool else { return }

        startDismissingAlerts()
        guard let lastIconSet else {
            setAppIcon(randomBool ? .blue : .gray)
            return
        }

        setAppIcon(lastIconSet == .blue ? .gray : .blue)
    }
}

/* MARK: Dependency */

public enum AppIconServiceDependency: DependencyKey {
    public static func resolve(_: DependencyValues) -> AppIconService {
        .init()
    }
}

public extension DependencyValues {
    var appIconService: AppIconService {
        get { self[AppIconServiceDependency.self] }
        set { self[AppIconServiceDependency.self] = newValue }
    }
}
