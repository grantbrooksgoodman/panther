//
//  SplashPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable cyclomatic_complexity file_length function_body_length type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking
import Translator

@MainActor
final class SplashPageViewService: ObservableObject {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.uiCacheInvalidationService) private var uiCacheInvalidationService: UICacheInvalidationService

    // MARK: - Properties

    var initializationProgress: CGFloat = 0 {
        didSet {
            percentageLabelText = initializationProgress >= 1 ? "100%" : "\(initializationProgress.roundedString)%"
            guard initializationProgress == 1 else { return }
            Task.delayed(by: .seconds(2)) { @MainActor in
                // Skip if a new initialization has since begun.
                guard initializationProgress == 1 else { return }
                initializationProgress = 0
            }
        }
    }

    @Published private(set) var loadingLabelText = ""
    @Published private(set) var percentageLabelText = ""

    private var didAttemptDatabaseRepair = false
    private var didSurpassQuickLoadTimeoutDuration = false
    private var initializationStartDate = Date(timeIntervalSince1970: 0)
    @SharedState(\.networkHealth) private var networkHealth

    // MARK: - Computed Properties

    var shouldShowLoadingLabel: Bool {
        didAttemptDatabaseRepair || didSurpassQuickLoadTimeoutDuration
    }

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    func initializeBundle(fromRetry: Bool) async throws(Exception) {
        /* MARK: Service Setup */

        Toast.hide()
        loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

        if !fromRetry {
            didSurpassQuickLoadTimeoutDuration = false
            initializationProgress = 0
            initializationStartDate = .now

            Task.delayed(by: .milliseconds(2500)) { @MainActor in
                guard !Task.isCancelled,
                      initializationProgress <= 0.6 else { return }
                didSurpassQuickLoadTimeoutDuration = true
            }
        }

        /* MARK: AKCore Delegate Setup */

        alertKitConfig.registerReportDelegate(ErrorReportingService())
        alertKitConfig.registerTranslationDelegate(networking.hostedTranslation)

        /* MARK: Breadcrumbs Capture Setup */

        BreadcrumbsCaptureService.shared.setCaptureGranularity(.narrow)

        /* MARK: Store Observation Setup */

        uiCacheInvalidationService.startObserving()

        /* MARK: Offline User Setup */

        guard build.isOnline else {
            guard let currentUser = clientSession.entity.user.currentUser else {
                return Logger.log(
                    .init(
                        "No persisted user exists.",
                        isReportable: false,
                        metadata: .init(sender: self)
                    )
                )
            }

            initializationProgress = 1
            return core.utils.setLanguageCode(
                currentUser.languageCode
            )
        }

        /* MARK: Pre-flight Configuration */

        Networking.config.setIsEnhancedDialogTranslationEnabled(true)
        Networking.config.setEnhancedTranslationStatusVerbosity(.successOnly)

        Logger.setReportsErrorsAutomatically(
            !UIDevice.isSimulator && build.milestone == .generalRelease
        )

        services.review.incrementAppOpenCount()

        /* MARK: Anonymous Sign-In */

        guard !Task.isCancelled else { return }
        _ = try? await LockIsolated(networking.auth)
            .wrappedValue
            .signInAnonymously()

        /* MARK: Parallel Initialization */

        guard !Task.isCancelled else { return }

        // Launch the heaviest independent network calls concurrently.
        async let resolveCurrentUserResult = clientSession.entity.user.resolveCurrentUser()
        async let resolveLanguageCodeResult: Void = clientSession.resolveAndSetLanguageCode()
        async let resolveValuesResult: Void = services.metadata.resolveValues()

        do {
            guard !Task.isCancelled else { return }
            if User.currentUserID != nil {
                try await resolveLanguageCodeResult
            }

            try await resolveValuesResult
        } catch let error as Exception {
            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }

        initializationProgress += 0.02

        /* MARK: UpdateService Setup */

        guard !Task.isCancelled else { return }
        services.update.incrementRelaunchCountIfNeeded()
        try await services.update.promptToUpdateIfNeeded()

        initializationProgress += 0.01

        /* MARK: Cache Setup */

        // Runs while resolveCurrentUser() continues in the background.
        if let currentUserID = User.currentUserID {
            do {
                guard !Task.isCancelled else { return }
                let cacheStatus = try await services.remoteCache.cacheStatus(
                    userID: currentUserID
                )

                initializationProgress += 0.02

                if cacheStatus == .invalid {
                    guard !Task.isCancelled else { return }
                    try await services.remoteCache.setCacheStatus(
                        .valid,
                        userID: currentUserID
                    )

                    Application.reset(preserveCurrentUserID: true)
                    return try await initializeBundle(fromRetry: true)
                }
            } catch {
                if !error.isEqual(to: .Networking.Database.noValueExists) {
                    Logger.log(error)
                }
            }
        }

        /* MARK: UserSessionService Setup */

        // User resolution likely completed during the metadata + update + cache gates above.
        do {
            guard !Task.isCancelled else { return }
            try await resolveCurrentUserResult
            initializationProgress += 0.2

            guard let currentUser = clientSession.entity.user.currentUser else {
                throw Exception(
                    "Failed to resolve current user.",
                    metadata: .init(sender: self)
                )
            }

            /* MARK: UI Setup */

            Networking.config.setIsEnhancedDialogTranslationEnabled(
                currentUser.aiEnhancedTranslationsEnabled
            )

            checkPrevaricationMode(currentUser.phoneNumber)
            loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

            /* MARK: Device ID Update */

            // Must complete before the Firebase observer starts (post-splash),
            // otherwise the observer sees the change and triggers sign-out.
            guard !Task.isCancelled else { return }
            try await currentUser.updateDeviceIDIfNeeded()

            /* MARK: Contact Pair Archive + Temporary Cache Population */

            do {
                guard !Task.isCancelled else { return }
                try await ContactService.syncIfNeeded()
            } catch {
                Logger.log(error)
            }

            if (currentUser.conversationIDs ?? []).count > 20,
               clientSession.store.conversations.isEmpty {
                let database = LockIsolated(networking.database)
                Task.detached(priority: .utility) {
                    do throws(Exception) {
                        guard !Task.isCancelled else { return }
                        try await database.wrappedValue.populateTemporaryCaches()
                    } catch {
                        Logger.log(error)
                    }
                }
            }

            /* MARK: Conversation Resolution */

            guard !Task.isCancelled else { return }
            clientSession.entity.conversation.setCurrentConversation(nil)
            try await clientSession.entity.user.resolveCurrentUser(
                and: .allDataTypes
            )

            initializationProgress = 1

            /* MARK: Post-launch Maintenance */

            Task { [weak self] in
                guard let self,
                      !Task.isCancelled else { return }

                let pushTokenService = LockIsolated(services.pushToken)
                if Networking.config.environment != .staging {
                    do throws(Exception) {
                        guard !Task.isCancelled else { return }
                        try await pushTokenService
                            .wrappedValue
                            .prunePushTokensForCurrentUser()
                    } catch {
                        Logger.log(
                            error,
                            with: .toastInPrerelease
                        )
                    }
                }

                do throws(Exception) {
                    guard !Task.isCancelled else { return }
                    try await TypingIndicatorService
                        .resetTypingIndicatorStatusForCurrentUser()
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }

                do throws(Exception) {
                    let currentUser = LockIsolated(currentUser)
                    guard !Task.isCancelled else { return }
                    try await services
                        .notification
                        .setBadgeNumber(
                            currentUser.wrappedValue.calculateBadgeNumber()
                        )
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }

                do throws(Exception) {
                    guard !Task.isCancelled else { return }
                    try await services
                        .penPals
                        .updateSharingDataForKnownUsers()
                } catch {
                    Logger.log(
                        error,
                        with: .toastInPrerelease
                    )
                }
            }
        } catch let error as Exception {
            guard !error.isEqual(to: .currentUserIDNotSet) else {
                return initializationProgress = 1
            }

            throw error
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    /// `.errorAlertDismissed`
    func performRetryHandler() async throws(Exception) {
        func attemptDatabaseRepair() async throws(Exception) {
            didAttemptDatabaseRepair = true
            loadingLabelText = "\(Localized(.repairingData).wrappedValue)..."

            do {
                try await networking.integrityService.repairDatabase()
            } catch {
                if error.isEqual(to: .updateRequired) {
                    services.update.isForcedUpdateRequiredSubject.send(true)
                    return
                }

                throw error
            }
        }

        if !didAttemptDatabaseRepair {
            try await attemptDatabaseRepair()
        } else {
            Application.reset()
            didAttemptDatabaseRepair = false
        }
    }

    /// `.initializedBundle`
    func presentErrorAlert(_ exception: Exception) async {
        let mockGenericException: Exception = .init(metadata: .init(sender: self))
        let mockTimedOutException: Exception = .timedOut(metadata: .init(sender: self))

        let notGenericDescriptor = exception.userFacingDescriptor != mockGenericException.userFacingDescriptor
        let notTimedOutDescriptor = exception.userFacingDescriptor != mockTimedOutException.userFacingDescriptor
        let hasUserFacingDescriptor = exception.descriptor != exception.userFacingDescriptor

        let shouldTranslate = hasUserFacingDescriptor && notGenericDescriptor && notTimedOutDescriptor

        var translationOptionKeys: [AKErrorAlert.TranslationOptionKey] = shouldTranslate ? [.errorDescription] : []
        if exception.isReportable {
            translationOptionKeys.append(.sendErrorReportButtonTitle)
        }

        await AKErrorAlert(
            exception,
            dismissButtonTitle: Localized(.tryAgain).wrappedValue
        ).present(translating: translationOptionKeys)
    }

    /// Returns `true` if a complete cached user is available and
    /// either the network health degrades to poor or the fallback
    /// deadline elapses before bundle initialization settles.
    func resolveCachedUserIfPoorNetwork() async -> Bool {
        guard let currentUser = clientSession.entity.user.currentUser,
              let conversations = currentUser.conversations,
              conversations.allSatisfy({ $0.messages != nil }),
              conversations.allSatisfy({ $0.users != nil }) else {
            Logger.log(.init(
                "Insufficient data to load from cached user.",
                isReportable: false,
                metadata: .init(sender: self)
            ))
            return false
        }

        // The values stream doesn't replay the current value, so
        // check it first; also resolves instantly on retry, when the
        // health is already known to be poor.
        if networking.health.health.tier != .poor {
            let healthChanges = $networkHealth.changes
            let shouldTriggerDeferredResolution = await withTaskGroup(
                of: Void.self
            ) { taskGroup in
                taskGroup.addTask {
                    for await health in healthChanges where health.tier == .poor {
                        return
                    }
                }

                taskGroup.addTask {
                    // Fallback deadline; on a dead network, the
                    // health estimator has no evidence until the
                    // first censored timeout sample lands.
                    try? await Task.sleep(for: .seconds(5))
                }

                _ = await taskGroup.next()
                taskGroup.cancelAll()
                return !Task.isCancelled
            }

            guard shouldTriggerDeferredResolution else { return false }
        }

        initializationProgress = 0.9
        core.utils.setLanguageCode(
            currentUser.languageCode
        )

        Task(priority: .background) { @MainActor [weak self] in
            await self?.waitForUsableNetworkHealth()
            do throws(Exception) {
                try await self?.clientSession.entity.user.resolveCurrentUser(
                    and: .allDataTypes
                )

                Logger.log(
                    "Deferred resolution of current user data was successful.",
                    sender: self ?? SplashPageViewService.self
                )
            } catch {
                Logger.log(error)
            }
        }

        return true
    }

    private func checkPrevaricationMode(_ phoneNumber: PhoneNumber) {
        let isUsingTestAccount = [
            "15555555555",
            "18888888888",
        ].contains(phoneNumber.compiledNumberString)

        guard isUsingTestAccount,
              build.milestone == .generalRelease,
              Networking.config.environment == .production,
              services.metadata.isPrevaricationModeEnabled == true else { return }

        Application.isInPrevaricationMode = true
        core.ui.toggleGlassTinting(on: false)
        Toast.overrideDefaultColorPalette(.init(
            background: .init(uiColor: .init(hex: 0xF8F8F8))
        ))

        ThemeService.setTheme(
            UITheme.prevaricationMode,
            checkStyle: false
        )
    }

    /// Suspends until the network health becomes usable – `.fair`
    /// or `.good` – returning immediately if it already is.
    private func waitForUsableNetworkHealth() async {
        let usableTiers: [NetworkHealthTier] = [
            .fair,
            .good,
        ]

        // The values stream doesn't replay the current value, so
        // check it first.
        if let tier = networking.health.health.tier,
           usableTiers.contains(tier) { return }

        for await health in $networkHealth.changes {
            guard let tier = health.tier,
                  usableTiers.contains(tier) else { continue }
            return
        }
    }
}

// swiftlint:enable cyclomatic_complexity file_length function_body_length type_body_length
