//
//  ConnectionStatusService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Use ``ConnectionStatusService`` to run effects when network connectivity changes.
///
/// The service observes network reachability for the lifetime of the instance, running its
/// registered effects when connectivity is lost and when it is restored.
final class ConnectionStatusService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.notificationCenter) private var notificationCenter: NotificationCenter

    // MARK: - Properties

    private var isAwaitingConnectionRestoration = false
    private var reachability: Reachability?
    @LockIsolated private var uponConnectionChanged = [ConnectionStatusServiceEffectID: () -> Void]()

    // MARK: - Init

    /// Creates a connection status service and begins observing network reachability.
    init() {
        isAwaitingConnectionRestoration = !build.isOnline

        do {
            try reachability = .init()
            try reachability?.startNotifier()
        } catch {
            Logger.log(.init(error, metadata: .init(sender: self)))
        }

        notificationCenter.addObserver(self, name: .reachabilityChanged) { _ in
            guard self.build.isOnline else {
                self.runEffects()
                self.isAwaitingConnectionRestoration = true
                return
            }

            guard self.isAwaitingConnectionRestoration else { return }
            self.runEffects()
            self.isAwaitingConnectionRestoration = false
        }
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

    /// Registers an effect to run when connection status changes.
    ///
    /// Registering a new effect with the same identifier replaces the existing one.
    ///
    /// - Parameters:
    ///   - id: The identifier under which to register the effect.
    ///   - effect: The effect to run.
    ///
    /// - Warning: The effect runs perpetually, upon each change in connection status. Call
    ///   ``removeEffect(_:)`` or ``clearAllEffects()`` if this is not the desired behavior.
    func addEffectUponConnectionChanged(
        id: ConnectionStatusServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        $uponConnectionChanged[id] = effect
    }

    /// Removes every registered effect.
    func clearAllEffects() {
        uponConnectionChanged = .init()
    }

    /// Removes the effect registered under the given identifier.
    ///
    /// - Parameter id: The identifier of the effect to remove.
    func removeEffect(_ id: ConnectionStatusServiceEffectID) {
        $uponConnectionChanged[id] = nil
    }

    // MARK: - Auxiliary

    private func runEffects() {
        let effects = $uponConnectionChanged.withValue { Array($0.values) }
        effects.forEach { $0() }
    }
}
