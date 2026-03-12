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

// swiftlint:disable identifier_name

final class ChatPageStateService {
    // MARK: - Properties

    private(set) var isPresented: Bool {
        didSet { didSetIsPresented() }
    }

    private(set) var isWaitingToUpdateConversations: Bool {
        didSet { didSetIsWaitingToUpdateConversations() }
    }

    @LockIsolated private var uponIsPresentedChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsPresentedChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsWaitingToUpdateConversationsChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    @LockIsolated private var uponIsWaitingToUpdateConversationsChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()

    // MARK: - Init

    init(isPresented: Bool, isWaitingToUpdateConversations: Bool) {
        self.isPresented = isPresented
        self.isWaitingToUpdateConversations = isWaitingToUpdateConversations
    }

    // MARK: - Setters

    func setIsPresented(_ isPresented: Bool) {
        self.isPresented = isPresented
    }

    func setIsWaitingToUpdateConversations(_ isWaitingToUpdateConversations: Bool) {
        self.isWaitingToUpdateConversations = isWaitingToUpdateConversations
    }

    // MARK: - Effect Addition

    /// Adds an effect to be run once, upon a change in value of `isPresented`.
    func addEffectUponIsPresented(
        changedTo state: Bool,
        id: ChatPageStateServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return $uponIsPresentedChangedToFalse[id] = effect }
        $uponIsPresentedChangedToTrue[id] = effect
    }

    /// Adds an effect to be run once, upon a change in value of `isWaitingToUpdateConversations`.
    func addEffectUponIsWaitingToUpdateConversations(
        changedTo state: Bool,
        id: ChatPageStateServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else { return $uponIsWaitingToUpdateConversationsChangedToFalse[id] = effect }
        $uponIsWaitingToUpdateConversationsChangedToTrue[id] = effect
    }

    // MARK: - Did Set

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

    private func didSetIsWaitingToUpdateConversations() {
        switch isWaitingToUpdateConversations {
        case true:
            let uponIsWaitingToUpdateConversationsChangedToTrue = drainEffects($uponIsWaitingToUpdateConversationsChangedToTrue)
            guard !uponIsWaitingToUpdateConversationsChangedToTrue.isEmpty else { return }

            Logger.log(
                .init(
                    "Running effects for change of \"isWaitingToUpdateConversations\" to TRUE.",
                    isReportable: false,
                    userInfo: ["EnqueuedEffectIDs": uponIsWaitingToUpdateConversationsChangedToTrue.keys.map(\.rawValue)],
                    metadata: .init(sender: self)
                ),
                domain: .chatPageState
            )

            runEffects(uponIsWaitingToUpdateConversationsChangedToTrue)

        case false:
            let uponIsWaitingToUpdateConversationsChangedToFalse = drainEffects($uponIsWaitingToUpdateConversationsChangedToFalse)
            guard !uponIsWaitingToUpdateConversationsChangedToFalse.isEmpty else { return }

            Logger.log(
                .init(
                    "Running effects for change of \"isWaitingToUpdateConversations\" to FALSE.",
                    isReportable: false,
                    userInfo: ["EnqueuedEffectIDs": uponIsWaitingToUpdateConversationsChangedToFalse.keys.map(\.rawValue)],
                    metadata: .init(sender: self)
                ),
                domain: .chatPageState
            )

            runEffects(uponIsWaitingToUpdateConversationsChangedToFalse)
        }
    }

    // MARK: - Auxiliary

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

// swiftlint:enable identifier_name
