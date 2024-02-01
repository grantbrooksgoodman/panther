//
//  ChatPageStateService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 01/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux

// swiftlint:disable identifier_name

public final class ChatPageStateService {
    // MARK: - Properties

    // Bool
    public private(set) var isPresented: Bool {
        didSet { didSetIsPresented() }
    }

    public private(set) var isWaitingToUpdateConversations: Bool {
        didSet { didSetIsWaitingToUpdateConversations() }
    }

    // Dictionary
    public private(set) var uponIsPresentedChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    public private(set) var uponIsPresentedChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()
    public private(set) var uponIsWaitingToUpdateConversationsChangedToFalse = [ChatPageStateServiceEffectID: () -> Void]()
    public private(set) var uponIsWaitingToUpdateConversationsChangedToTrue = [ChatPageStateServiceEffectID: () -> Void]()

    // MARK: - Init

    public init(isPresented: Bool, isWaitingToUpdateConversations: Bool) {
        self.isPresented = isPresented
        self.isWaitingToUpdateConversations = isWaitingToUpdateConversations
    }

    // MARK: - Setters

    public func setIsPresented(_ isPresented: Bool) {
        self.isPresented = isPresented
    }

    public func setIsWaitingToUpdateConversations(_ isWaitingToUpdateConversations: Bool) {
        self.isWaitingToUpdateConversations = isWaitingToUpdateConversations
    }

    // MARK: - Effect Addition

    /// Adds an effect to be run once, upon a change in value of `isPresented`.
    public func addEffectUponIsPresented(
        changedTo state: Bool,
        id: ChatPageStateServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else {
            uponIsPresentedChangedToFalse[id] = effect
            return
        }

        uponIsPresentedChangedToTrue[id] = effect
    }

    /// Adds an effect to be run once, upon a change in value of `isWaitingToUpdateConversations`.
    public func addEffectUponIsWaitingToUpdateConversations(
        changedTo state: Bool,
        id: ChatPageStateServiceEffectID,
        _ effect: @escaping () -> Void
    ) {
        guard state else {
            uponIsWaitingToUpdateConversationsChangedToFalse[id] = effect
            return
        }

        uponIsWaitingToUpdateConversationsChangedToTrue[id] = effect
    }

    // MARK: - Did Set

    private func didSetIsPresented() {
        switch isPresented {
        case true:
            guard !uponIsPresentedChangedToTrue.isEmpty else { return }

            Logger.log(
                .init(
                    "Executing effects for change of \"isPresented\" to TRUE.",
                    extraParams: ["EnqueuedEffectIDs": uponIsPresentedChangedToTrue.keys.map(\.rawValue)],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .chatPageState
            )

            uponIsPresentedChangedToTrue.values.forEach { $0() }
            uponIsPresentedChangedToTrue = .init()

        case false:
            guard !uponIsPresentedChangedToFalse.isEmpty else { return }

            Logger.log(
                .init(
                    "Executing effects for change of \"isPresented\" to FALSE.",
                    extraParams: ["EnqueuedEffectIDs": uponIsPresentedChangedToFalse.keys.map(\.rawValue)],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .chatPageState
            )

            uponIsPresentedChangedToFalse.values.forEach { $0() }
            uponIsPresentedChangedToFalse = .init()
        }
    }

    private func didSetIsWaitingToUpdateConversations() {
        switch isWaitingToUpdateConversations {
        case true:
            guard !uponIsWaitingToUpdateConversationsChangedToTrue.isEmpty else { return }

            Logger.log(
                .init(
                    "Executing effects for change of \"isWaitingToUpdateConversations\" to TRUE.",
                    extraParams: ["EnqueuedEffectIDs": uponIsWaitingToUpdateConversationsChangedToTrue.keys.map(\.rawValue)],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .chatPageState
            )

            uponIsWaitingToUpdateConversationsChangedToTrue.values.forEach { $0() }
            uponIsWaitingToUpdateConversationsChangedToTrue = .init()

        case false:
            guard !uponIsWaitingToUpdateConversationsChangedToFalse.isEmpty else { return }

            Logger.log(
                .init(
                    "Executing effects for change of \"isWaitingToUpdateConversations\" to FALSE.",
                    extraParams: ["EnqueuedEffectIDs": uponIsWaitingToUpdateConversationsChangedToFalse.keys.map(\.rawValue)],
                    metadata: [self, #file, #function, #line]
                ),
                domain: .chatPageState
            )

            uponIsWaitingToUpdateConversationsChangedToFalse.values.forEach { $0() }
            uponIsWaitingToUpdateConversationsChangedToFalse = .init()
        }
    }
}

// swiftlint:enable identifier_name
