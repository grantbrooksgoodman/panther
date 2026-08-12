//
//  UIViewController+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SafariServices
import UIKit

/* Proprietary */
import AppSubsystem

extension UIViewController {
    // MARK: - Properties

    /// A one-time token that exchanges the implementation of `present(_:animated:completion:)`
    /// with a version that customizes `SFSafariViewController` presentation.
    ///
    /// The exchanged implementation forces a light interface style on presented
    /// `SFSafariViewController` instances and covers their top and bottom bars with overlay
    /// views matched to the app's appearance. Presentation of all other view controllers is
    /// unaffected.
    ///
    /// Evaluating this property performs the exchange; subsequent evaluations have no effect.
    /// ``Application/initialize()`` evaluates it once at launch.
    ///
    /// - SeeAlso: ``UIViewController/swizzleViewWillDisappear``
    static let swizzlePresent: Void = {
        guard let original = class_getInstanceMethod(UIViewController.self, #selector(present(_:animated:completion:))),
              let swizzled = class_getInstanceMethod(UIViewController.self, #selector(_present(_:animated:completion:))) else { return }
        method_exchangeImplementations(original, swizzled)
    }()

    /// A one-time token that exchanges the implementation of `viewWillDisappear(_:)` with a
    /// version that removes the overlay views added during `SFSafariViewController`
    /// presentation.
    ///
    /// Evaluating this property performs the exchange; subsequent evaluations have no effect.
    /// ``Application/initialize()`` evaluates it once at launch.
    ///
    /// - SeeAlso: ``UIViewController/swizzlePresent``
    static let swizzleViewWillDisappear: Void = {
        guard let original = class_getInstanceMethod(UIViewController.self, #selector(viewWillDisappear(_:))),
              let swizzled = class_getInstanceMethod(UIViewController.self, #selector(_viewWillDisappear(_:))) else { return }
        method_exchangeImplementations(original, swizzled)
    }()

    // MARK: - Methods

    @objc
    private func _present(
        _ viewControllerToPresent: UIViewController,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.build.isDeveloperModeEnabled) var isDeveloperModeEnabled: Bool
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        guard let safariViewController = viewControllerToPresent as? SFSafariViewController else {
            return _present(
                viewControllerToPresent,
                animated: animated,
                completion: completion
            )
        }

        let textFieldDigits = uiApplication
            .presentedViews
            .compactMap { $0 as? UITextField }
            .unique
            .first?
            .text?
            .digits

        if !isDeveloperModeEnabled {
            guard textFieldDigits != "5555555555",
                  textFieldDigits != "8888888888" else {
                return _present(
                    viewControllerToPresent,
                    animated: animated,
                    completion: completion
                )
            }
        }

        safariViewController.overrideUserInterfaceStyle = .light

        _present(
            safariViewController,
            animated: false
        ) {
            guard let mainWindow = uiApplication.mainWindow else {
                completion?()
                return
            }

            let navigationBarHeight = NavigationBar.height

            let bottomOverlayView = UIView(frame: .init(
                x: 0,
                y: mainWindow.bounds.maxY - (navigationBarHeight + 30),
                width: mainWindow.frame.width,
                height: navigationBarHeight + 30
            ))

            let topOverlayView = UIView(frame: .init(
                x: isDeveloperModeEnabled ? 70 : 0,
                y: mainWindow.safeAreaInsets.top,
                width: mainWindow.frame.width - (isDeveloperModeEnabled ? 70 : 0),
                height: navigationBarHeight
            ))

            bottomOverlayView.backgroundColor = UIApplication.iOS26IsAvailable ? .white : .init(hex: 0xF8F8F8)
            topOverlayView.backgroundColor = UIApplication.iOS26IsAvailable ? .white : .init(hex: 0xF8F8F8)

            bottomOverlayView.tag = coreUI.semTag(for: "SF_SAFARI_VIEW_CONTROLLER_OVERLAY_VIEW")
            topOverlayView.tag = coreUI.semTag(for: "SF_SAFARI_VIEW_CONTROLLER_OVERLAY_VIEW")

            mainWindow.addSubview(bottomOverlayView)
            mainWindow.addSubview(topOverlayView)

            completion?()
        }
    }

    @objc
    private func _viewWillDisappear(
        _ animated: Bool
    ) {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.uiApplication.mainWindow) var mainWindow: UIWindow?

        guard self is SFSafariViewController else { return _viewWillDisappear(animated) }
        mainWindow?.removeSubviews(
            for: "SF_SAFARI_VIEW_CONTROLLER_OVERLAY_VIEW",
            animated: false
        )

        _viewWillDisappear(animated)
    }
}
