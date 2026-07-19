//
//  SceneDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking

/// The delegate that manages the app's window scene lifecycle.
///
/// `SceneDelegate` creates and configures the root window when a
/// scene connects, and forwards trait collection changes to the
/// subsystem.
///
/// Per-scene setup occurs in ``scene(_:willConnectTo:options:)``,
/// which instantiates the root window scene and attaches the app's
/// root SwiftUI view hierarchy.
final class SceneDelegate: UIResponder, UIGestureRecognizerDelegate, UIWindowSceneDelegate {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiCacheInvalidationService) private var uiCacheInvalidationService: UICacheInvalidationService

    // MARK: - Properties

    /// The window associated with this scene.
    var window: UIWindow?

    private var networkActivityIndicatorWindow: UIWindow?

    // MARK: - UIScene

    /// Creates the root window and attaches the app's view hierarchy.
    ///
    /// This method calls
    /// ``RootWindowScene/instantiate(_:rootView:)`` to build the
    /// window scene with ``RootView`` as its content.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        window = RootWindowScene.instantiate(
            scene,
            rootView: RootView()
        )

        // Hack to get the network activity indicator to appear
        // above all other content.
        if let windowScene = scene as? UIWindowScene {
            let activityIndicatorWindow = UIWindow(windowScene: windowScene)

            activityIndicatorWindow.backgroundColor = .clear
            activityIndicatorWindow.isUserInteractionEnabled = false
            activityIndicatorWindow.windowLevel = .statusBar + 1

            let hostingController = UIHostingController(
                rootView: Color.clear
                    .ignoresSafeArea()
                    .indicatesNetworkActivity()
            )

            hostingController.view.backgroundColor = .clear

            activityIndicatorWindow.rootViewController = hostingController
            activityIndicatorWindow.isHidden = false
            networkActivityIndicatorWindow = activityIndicatorWindow
        }

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: nil
        )

        tapGesture.delegate = self
        window?.addGestureRecognizer(tapGesture)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        Observables.traitCollectionChanged.trigger()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        clientSession.store.flushNow()
        uiCacheInvalidationService.refreshNotificationExtensionNameMap()

        Task.background {
            if let badgeNumber = await clientSession
                .entity
                .user
                .currentUser?
                .calculateBadgeNumber() {
                do throws(Exception) {
                    try await services.notification.setBadgeNumber(badgeNumber)
                } catch {
                    Logger.log(error)
                }
            }
        }
    }

    // MARK: - UIWindowScene

    /// Notifies the subsystem when the trait collection changes.
    ///
    /// This method calls
    /// ``RootWindowScene/traitCollectionChanged()`` to propagate
    /// appearance changes – such as switching between light and dark
    /// mode – throughout the view hierarchy.
    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation:
        UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        RootWindowScene.traitCollectionChanged()
        Observables.traitCollectionChanged.trigger()
    }

    // MARK: - UIGestureRecognizer

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard build.milestone == .generalRelease,
              Networking.config.environment == .production,
              let view = touch.view,
              let currentUserPhoneNumber = clientSession
              .entity
              .user
              .currentUser?
              .phoneNumber,
              ["15555555555", "18888888888"].contains(
                  currentUserPhoneNumber.compiledNumberString
              ) else { return false }

        services.analytics.logEvent(
            .touchUiElement,
            additionalUserInfo: ["ui_element": view.descriptor]
        )

        return false
    }
}
