//
//  ChatPageStateService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Use ``ChatPageStateService`` to track whether the chat page is presented and to schedule
/// one-shot effects on presentation changes.
///
/// The service is main-actor isolated. ``isPresented`` is written only on the main actor, in the
/// same turn that drains and runs the effects registered for the new value. A registered
/// effect therefore runs exactly once, for the assignment it was registered against, and no
/// other writer can interleave between the write and the drain.
@MainActor
final class ChatPageStateService {
    // MARK: - Properties

    /// A Boolean value that indicates whether the chat page is presented.
    ///
    /// Written only through ``setIsPresented(_:)``, which runs the effects registered for
    /// the new value in the same turn.
    private(set) var isPresented: Bool

    private var uponIsPresentedChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    private var uponIsPresentedChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()

    // MARK: - Init

    /// Creates a chat page state service with the given initial presentation state.
    ///
    /// No effects run for the initial value.
    ///
    /// - Parameter isPresented: A Boolean value that indicates whether the chat page is
    ///   presented.
    nonisolated init(isPresented: Bool) {
        self.isPresented = isPresented
    }

    // MARK: - Setters

    /// Sets whether the chat page is presented.
    ///
    /// Each assignment runs – and clears – the effects registered for the new value,
    /// whether or not the value changed. The registry is drained before the effects run, so an
    /// effect that registers a new effect for the same value keeps it for the next assignment.
    ///
    /// - Parameter isPresented: A Boolean value that indicates whether the chat page is
    ///   presented.
    func setIsPresented(_ isPresented: Bool) {
        self.isPresented = isPresented

        let effects: [ChatPageStateServiceEffectID: () -> Void]
        if isPresented {
            effects = uponIsPresentedChangedToTrue
            uponIsPresentedChangedToTrue = [:]
        } else {
            effects = uponIsPresentedChangedToFalse
            uponIsPresentedChangedToFalse = [:]
        }

        guard !effects.isEmpty else { return }

        Logger.log(
            .init(
                "Running effects for change of \"isPresented\" to \(isPresented ? "TRUE" : "FALSE").",
                isReportable: false,
                userInfo: ["EnqueuedEffectIDs": effects.keys.map(\.rawValue)],
                metadata: .init(sender: self)
            ),
            domain: .chatPageState
        )

        effects.values.forEach { $0() }
    }

    // MARK: - Effect Addition

    /// Registers an effect to run once, the next time ``isPresented`` is set to the given
    /// value.
    ///
    /// The effect is cleared after it runs. Registering a new effect with the same identifier
    /// and target value replaces the existing one.
    ///
    /// - Parameters:
    ///   - state: The value of ``isPresented`` that triggers the effect.
    ///   - id: The identifier under which to register the effect.
    ///   - effect: The effect to run.
    func addEffectUponIsPresented(
        changedTo state: Bool,
        id: ChatPageStateServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return uponIsPresentedChangedToFalse[id] = effect }
        uponIsPresentedChangedToTrue[id] = effect
    }
}
