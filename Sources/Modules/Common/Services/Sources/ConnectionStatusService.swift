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
///
/// The service is main-actor isolated. `Reachability` delivers its change notifications on the
/// main queue, and every registration, removal, and run happens on the main actor, so the
/// registry needs no lock and no other context can interleave with a run.
@MainActor
final class ConnectionStatusService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build

    // MARK: - Properties

    /// Boxed so the nonisolated `deinit` can stop the notifier.
    private let reachability = UncheckedLockIsolated<Reachability?>(nil)

    private var isAwaitingConnectionRestoration = false
    private var uponConnectionChanged = [ConnectionStatusServiceEffectID: () -> Void]()

    // MARK: - Init

    /// Creates a connection status service and begins observing network reachability.
    nonisolated init() {
        @Dependency(\.build) var build: Build
        @Dependency(\.notificationCenter) var notificationCenter: NotificationCenter

        isAwaitingConnectionRestoration = !build.isOnline

        do {
            try reachability.wrappedValue = .init()
            try reachability.wrappedValue?.startNotifier()
        } catch {
            Logger.log(.init(error, metadata: .init(sender: self)))
        }

        // `Reachability` is created with its default notification queue,
        // the main queue, so the observer runs on the main actor already
        // and asserts that rather than hopping to it.
        notificationCenter.addObserver(
            self,
            name: .reachabilityChanged
        ) { _ in
            MainActor.assumeIsolated {
                self.reachabilityDidChange()
            }
        }
    }

    // MARK: - Object Lifecycle

    deinit {
        @Dependency(\.notificationCenter) var notificationCenter: NotificationCenter

        reachability.wrappedValue?.stopNotifier()
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
        uponConnectionChanged[id] = effect
    }

    /// Removes every registered effect.
    func clearAllEffects() {
        uponConnectionChanged = .init()
    }

    /// Removes the effect registered under the given identifier.
    ///
    /// - Parameter id: The identifier of the effect to remove.
    func removeEffect(_ id: ConnectionStatusServiceEffectID) {
        uponConnectionChanged[id] = nil
    }

    // MARK: - Auxiliary

    private func reachabilityDidChange() {
        guard build.isOnline else {
            runEffects()
            isAwaitingConnectionRestoration = true
            return
        }

        guard isAwaitingConnectionRestoration else { return }
        runEffects()
        isAwaitingConnectionRestoration = false
    }

    private func runEffects() {
        // Snapshot the registry first so an effect that registers or
        // removes an effect does not mutate the collection being iterated.
        let effects = Array(uponConnectionChanged.values)
        effects.forEach { $0() }
    }
}
