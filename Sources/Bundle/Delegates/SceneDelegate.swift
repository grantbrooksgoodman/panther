//
//  SceneDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

final class SceneDelegate: UIResponder, UIGestureRecognizerDelegate, UIWindowSceneDelegate {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession.user.currentUser) private var currentUser: User?
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    var window: UIWindow?

    // MARK: - UIScene

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        window = RootWindowScene.instantiate(scene, rootView: RootView())

        let tapGesture = UITapGestureRecognizer(target: self, action: nil)
        tapGesture.delegate = self
        window?.addGestureRecognizer(tapGesture)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        Observables.traitCollectionChanged.trigger()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        Task.background {
            if let badgeNumber = await currentUser?.calculateBadgeNumber(),
               let exception = await services.notification.setBadgeNumber(badgeNumber) {
                Logger.log(exception)
            }
        }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    // MARK: - UIWindowScene

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
              let currentUser,
              ["15555555555", "18888888888"].contains(
                  currentUser.phoneNumber.compiledNumberString
              ) else { return false }

        services.analytics.logEvent(
            .touchUiElement,
            additionalUserInfo: ["ui_element": view.descriptor]
        )

        return false
    }
}
