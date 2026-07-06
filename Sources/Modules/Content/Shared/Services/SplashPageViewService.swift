//
//  SplashPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable cyclomatic_complexity function_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking
import Translator

@MainActor
// swiftlint:disable:next type_body_length
final class SplashPageViewService: ObservableObject {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices

    // MARK: - Properties

    var initializationProgress: CGFloat = 0 {
        didSet {
            percentageLabelText = initializationProgress >= 1 ? "100%" : "\(initializationProgress.roundedString)%"
            guard initializationProgress == 1 else { return }
            Task.delayed(by: .seconds(2)) { @MainActor in
                initializationProgress = 0
            }
        }
    }

    @Published private(set) var loadingLabelText = ""
    @Published private(set) var percentageLabelText = ""

    private var didAttemptDatabaseRepair = false
    private var didAttemptUserConversion = false
    private var didSurpassQuickLoadTimeoutDuration = false
    private var initializationStartDate = Date(timeIntervalSince1970: 0)

    // MARK: - Computed Properties

    var shouldShowLoadingLabel: Bool {
        didAttemptDatabaseRepair || didSurpassQuickLoadTimeoutDuration
    }

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    func initializeBundle() async throws(Exception) {
        /* MARK: Service Setup */

        Toast.hide()

        didSurpassQuickLoadTimeoutDuration = false
        initializationProgress = initializationProgress == 1 ? 0 : initializationProgress
        initializationStartDate = .now
        loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

        _ = Timeout(after: .seconds(3)) {
            Task { @MainActor [weak self] in
                guard let self,
                      initializationProgress <= 0.5 else { return }
                didSurpassQuickLoadTimeoutDuration = true
            }
        }

        /* MARK: AKCore Delegate Setup */

        alertKitConfig.registerReportDelegate(ErrorReportingService())
        alertKitConfig.registerTranslationDelegate(networking.hostedTranslation)

        /* MARK: Breadcrumbs Capture Setup */

        BreadcrumbsCaptureService.shared.setCaptureGranularity(.narrow)

        /* MARK: Offline User Setup */

        guard build.isOnline else {
            do {
                try clientSession.user.setOfflineCurrentUser()
            } catch {
                Logger.log(error)
            }

            initializationProgress = 1

            guard let currentUser = clientSession.user.currentUser else { return }
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

        if User.currentUserID == nil {
            let auth = LockIsolated(networking.auth)
            _ = try? await auth.wrappedValue.signInAnonymously()
        }

        /* MARK: Parallel Initialization */

        // Launch the heaviest independent network calls concurrently.
        async let resolveCurrentUserResult = clientSession.user.resolveCurrentUser()
        async let resolveLanguageCodeResult: Void = clientSession.resolveAndSetLanguageCode()
        async let resolveValuesResult: Void = services.metadata.resolveValues()

        do {
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

        services.update.incrementRelaunchCountIfNeeded()
        try await services.update.promptToUpdateIfNeeded()

        initializationProgress += 0.01

        /* MARK: Cache Setup */

        // Runs while resolveCurrentUser() continues in the background.
        if let currentUserID = User.currentUserID {
            do {
                let cacheStatus = try await services.remoteCache.cacheStatus(
                    userID: currentUserID
                )

                initializationProgress += 0.02

                if cacheStatus == .invalid {
                    Application.reset(preserveCurrentUserID: true)
                    do {
                        try await services.remoteCache.setCacheStatus(
                            .valid,
                            userID: currentUserID
                        )
                    } catch {
                        Logger.log(error)
                    }
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
            try await resolveCurrentUserResult
            initializationProgress += 0.2

            guard let currentUser = clientSession.user.currentUser else {
                throw Exception(
                    "Failed to resolve current user.",
                    metadata: .init(sender: self)
                )
            }

            /* MARK: Last Sign In Date Update */

            // Must complete before the Firebase observer starts (post-splash),
            // otherwise the observer sees the timestamp change and triggers sign-out.
            if RuntimeStorage.lastSignInDate == nil {
                try await currentUser.updateLastSignedInDate()
            }

            Networking.config.setIsEnhancedDialogTranslationEnabled(
                currentUser.aiEnhancedTranslationsEnabled
            )

            checkPrevaricationMode(currentUser.phoneNumber)
            loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

            /* MARK: Contact Pair Archive + Temporary Cache Population */

            do {
                try await ContactService.populateValuesIfNeeded()
            } catch {
                Logger.log(error)
            }

            @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
            if (currentUser.conversationIDs ?? []).count > 20,
               (conversationArchive ?? []).isEmpty {
                let database = LockIsolated(networking.database)
                do {
                    try await database.wrappedValue.populateTemporaryCaches()
                } catch {
                    Logger.log(error)
                }
            }

            /* MARK: Conversation Resolution */

            clientSession.conversation.setCurrentConversation(nil)
            try await clientSession.user.resolveCurrentUser(
                and: [
                    .conversations,
                    .users,
                ]
            )

            initializationProgress = 1

            /* MARK: Post-launch Maintenance */

            Task { [weak self] in
                guard let self else { return }

                let pushTokenService = LockIsolated(services.pushToken)
                if Networking.config.environment != .staging {
                    do throws(Exception) {
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

        if let currentUserID = User.currentUserID,
           !didAttemptUserConversion {
            didAttemptUserConversion = true
            do {
                try await networking.userService.legacy.convertUser(id: currentUserID)
            } catch {
                Logger.log(error)
                try await attemptDatabaseRepair()
            }
        } else if !didAttemptDatabaseRepair {
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
}

// swiftlint:enable cyclomatic_complexity function_body_length
