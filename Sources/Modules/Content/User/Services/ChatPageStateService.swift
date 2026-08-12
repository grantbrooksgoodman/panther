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
final class ChatPageStateService {
    // MARK: - Properties

    /// A Boolean value that indicates whether the chat page is presented.
    private(set) var isPresented: Bool {
        didSet { didSetIsPresented() }
    }

    @LockIsolated private var uponIsPresentedChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsPresentedChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()

    // MARK: - Init

    /// Creates a chat page state service with the given initial presentation state.
    ///
    /// - Parameter isPresented: A Boolean value that indicates whether the chat page is
    ///   presented.
    init(isPresented: Bool) {
        self.isPresented = isPresented
    }

    // MARK: - Setters

    /// Sets whether the chat page is presented.
    ///
    /// Each assignment runs – and clears – the effects registered for the assigned value,
    /// whether or not the value changed.
    ///
    /// - Parameter isPresented: A Boolean value that indicates whether the chat page is
    ///   presented.
    func setIsPresented(_ isPresented: Bool) {
        self.isPresented = isPresented
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
        guard state else { return $uponIsPresentedChangedToFalse[id] = effect }
        $uponIsPresentedChangedToTrue[id] = effect
    }

    // MARK: - Auxiliary

    private func didSetIsPresented() {
        switch isPresented {
        case true:
            let uponIsPresentedChangedToTrue = drainEffects($uponIsPresentedChangedToTrue)
            guard !uponIsPresentedChangedToTrue.isEmpty else { return }

            Logger.log(
                .init(
                    "Running effects for change of \"isPresented\" to TRUE.",
                    isReportable: false,
                    userInfo: ["EnqueuedEffectIDs": uponIsPresentedChangedToTrue.keys.map(\.rawValue)],
                    metadata: .init(sender: self)
                ),
                domain: .chatPageState
            )

            runEffects(uponIsPresentedChangedToTrue)

        case false:
            let uponIsPresentedChangedToFalse = drainEffects($uponIsPresentedChangedToFalse)
            guard !uponIsPresentedChangedToFalse.isEmpty else { return }

            Logger.log(
                .init(
                    "Running effects for change of \"isPresented\" to FALSE.",
                    isReportable: false,
                    userInfo: ["EnqueuedEffectIDs": uponIsPresentedChangedToFalse.keys.map(\.rawValue)],
                    metadata: .init(sender: self)
                ),
                domain: .chatPageState
            )

            runEffects(uponIsPresentedChangedToFalse)
        }
    }

    private func drainEffects(
        _ effects: LockIsolatedProjection<[ChatPageStateServiceEffectID: () -> Void]>
    ) -> [ChatPageStateServiceEffectID: () -> Void] {
        effects.withValue {
            guard !$0.isEmpty else { return [:] }
            let drained = $0
            $0 = [:]
            return drained
        }
    }

    private func runEffects(_ effects: [ChatPageStateServiceEffectID: () -> Void]) {
        effects.values.forEach { $0() }
    }
}
