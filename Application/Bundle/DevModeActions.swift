//
//  DevModeActions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 11/11/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

/**
 Use this extension to add new actions to the Developer Mode menu.
 */
public extension DevModeService {
    // MARK: - Properties

    static var toggleNetworkActivityIndicatorAction: DevModeAction {
        func toggleNetworkActivityIndicator() {
            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
            @Persistent(.indicatesNetworkActivity) var defaultsValue: Bool?

            guard let value = defaultsValue else {
                defaultsValue = true
                coreHUD.showSuccess(text: "ON")
                return
            }

            defaultsValue = !value
            coreHUD.showSuccess(text: !value == true ? "ON" : "OFF")
        }

        return .init(
            title: "Toggle Network Activity Indicator",
            perform: toggleNetworkActivityIndicator
        )
    }

    // MARK: - Custom Action Addition

    static func addCustomActions() {
        /* Add custom DevModeAction implementations here. */
        insertAction(toggleNetworkActivityIndicatorAction, at: actions.count - 2)
    }
}

public extension Persistent {
    convenience init(_ devModeServiceKey: UserDefaultsKeyDomain.DevModeServiceDefaultsKey) {
        self.init(.app(.devModeService(devModeServiceKey)))
    }
}

public extension UserDefaultsKeyDomain {
    enum DevModeServiceDefaultsKey: String {
        case indicatesNetworkActivity
    }
}
