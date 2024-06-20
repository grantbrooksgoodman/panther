//
//  ConversationsPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 18/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture

public struct ConversationsPageViewService {
    // MARK: - Dependencies

    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Methods

    public func viewAppeared() {
        userSession.startObservingCurrentUserChanges()

        Task {
            if let exception = await userSession.updatePushTokens() {
                Logger.log(exception)
            }
        }
    }

    /// `.resolveReturned(.success(_))`
    public func viewLoaded() {
        func showOfflineModeToast() {
            Observables.rootViewToast.value = .init(
                .capsule(style: .warning),
                message: Localized(.offlineMode).wrappedValue,
                perpetuation: .ephemeral(.seconds(10))
            )
        }

        /// - NOTE: Fixes a bug in which an offline startup would fail to properly set the navigation bar appearance.
        func updateAppearance() {
            Logger.log(
                "Intercepted offline startup navigation bar appearance bug.",
                domain: .bugPrevention,
                metadata: [self, #file, #function, #line]
            )

            coreGCD.after(.milliseconds(500)) {
                Observables.traitCollectionChanged.trigger()
            }
        }

        coreGCD.after(.seconds(1)) {
            Task { @MainActor in
                guard await services.permission.notificationPermissionStatus == .unknown else {
                    services.review.promptToReview()
                    return
                }

                _ = await services.permission.requestPermission(for: .notifications)
            }
        }

        services.connectionStatus.addEffectUponConnectionChanged(id: .showOfflineModeToast) {
            guard !build.isOnline else { return }
            showOfflineModeToast()
        }

        guard !build.isOnline else { return }
        updateAppearance()
        showOfflineModeToast()
    }

    /// `.pulledToRefresh`
    public func reloadData() async -> Callback<[Conversation], Exception> {
        func syncContactPairArchive() async -> Exception? {
            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: true),
               !exception.isEqual(toAny: [.mismatchedHashAndCallingCode, .notAuthorizedForContacts]) {
                return exception
            }

            return nil
        }

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case let .success(user):
            if let exception = await user.setConversations() {
                return .failure(exception)
            }

            if let exception = await user.conversations?.visibleForCurrentUser.setUsers() {
                return .failure(exception)
            }

            if let exception = await syncContactPairArchive() {
                return .failure(exception)
            }

            return .success(user.conversations ?? [])

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
