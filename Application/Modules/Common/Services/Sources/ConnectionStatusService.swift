//
//  ConnectionStatusService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public final class ConnectionStatusService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    private var isAwaitingConnectionRestoration = false
    private var reachability: Reachability?
    private var uponConnectionChanged = [ConnectionStatusServiceEffectID: () -> Void]()

    // MARK: - Init

    public init() {
        isAwaitingConnectionRestoration = !build.isOnline

        do {
            try reachability = .init()
            try reachability?.startNotifier()
        } catch {
            Logger.log(.init(error, metadata: [self, #file, #function, #line]))
        }

        notificationCenter.addObserver(
            self,
            selector: #selector(connectionChanged),
            name: .reachabilityChanged,
            object: nil
        )
    }

    // MARK: - Object Lifecycle

    deinit {
        reachability?.stopNotifier()
        notificationCenter.removeObserver(
            self,
            name: .reachabilityChanged,
            object: nil
        )
    }

    // MARK: - Effects

    /// Adds an effect to be run upon a change in connection status.
    /// - Warning: The provided effect will run perpetually, for each change in connection status. Call `clearAllEffects()` or `removeEffect(_:)` if this is not the desired behavior.
    public func addEffectUponConnectionChanged(
        id: ConnectionStatusServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        uponConnectionChanged[id] = effect
    }

    public func clearAllEffects() {
        uponConnectionChanged = .init()
    }

    public func removeEffect(_ id: ConnectionStatusServiceEffectID) {
        uponConnectionChanged[id] = nil
    }

    // MARK: - Auxiliary

    @objc
    private func connectionChanged() {
        guard build.isOnline else {
            uponConnectionChanged.values.forEach { $0() }
            isAwaitingConnectionRestoration = true
            return
        }

        guard isAwaitingConnectionRestoration else { return }
        uponConnectionChanged.values.forEach { $0() }
        isAwaitingConnectionRestoration = false
    }
}
