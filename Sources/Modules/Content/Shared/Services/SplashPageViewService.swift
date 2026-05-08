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

    var shouldShowLoadingLabel: Bool { didAttemptDatabaseRepair || didSurpassQuickLoadTimeoutDuration }

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    func initializeBundle() async -> Exception? {
        /* MARK: Service Setup */

        Toast.hide()

        didSurpassQuickLoadTimeoutDuration = false
        initializationProgress = initializationProgress == 1 ? 0 : initializationProgress
        initializationStartDate = .now
        loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

        _ = Timeout(after: .seconds(3)) {
            Task { @MainActor [weak self] in
                guard let self,
                      self.initializationProgress <= 0.5 else { return }
                self.didSurpassQuickLoadTimeoutDuration = true
            }
        }

        /* MARK: AKCore Delegate Setup */

        alertKitConfig.registerReportDelegate(ErrorReportingService())
        alertKitConfig.registerTranslationDelegate(networking.hostedTranslation)

        /* MARK: Breadcrumbs Capture Setup */

        BreadcrumbsCaptureService.shared.setCaptureGranularity(.narrow)

        /* MARK: Offline User Setup */

        guard build.isOnline else {
            if let exception = clientSession.user.setOfflineCurrentUser() {
                Logger.log(exception)
            }

            initializationProgress = 1

            guard let currentUser = clientSession.user.currentUser else { return nil }
            core.utils.setLanguageCode(currentUser.languageCode)
            return nil
        }

        /* MARK: Pre-flight Configuration */

        Networking.config.setIsEnhancedDialogTranslationEnabled(true)
        Networking.config.setEnhancedTranslationStatusVerbosity(.successOnly)

        Logger.setReportsErrorsAutomatically(
            !UIDevice.isSimulator && build.milestone == .generalRelease
        )

        services.review.incrementAppOpenCount()

        /* MARK: Parallel Initialization */

        // Launch the heaviest independent network calls concurrently.
        async let resolveAndSetLanguageCodeException = clientSession.user.resolveAndSetLanguageCode()
        async let resolveCurrentUserResult = clientSession.user.resolveCurrentUser()
        async let resolveValuesException = services.metadata.resolveValues()

        if User.currentUserID != nil,
           let exception = await resolveAndSetLanguageCodeException {
            return exception
        }

        if let exception = await resolveValuesException {
            return exception
        }

        initializationProgress += 0.02

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()
        if let exception = await services.update.promptToUpdateIfNeeded() {
            return exception
        }

        initializationProgress += 0.01

        /* MARK: Cache Setup */

        // Runs while resolveCurrentUser() continues in the background.
        if let currentUserID = User.currentUserID {
            let cacheStatusResult = await services.remoteCache.cacheStatus(userID: currentUserID)
            initializationProgress += 0.02

            switch cacheStatusResult {
            case let .success(cacheStatus):
                if cacheStatus == .invalid {
                    Application.reset(preserveCurrentUserID: true)
                    if let exception = await services.remoteCache.setCacheStatus(
                        .valid,
                        userID: currentUserID
                    ) {
                        Logger.log(exception)
                    }
                }

            case let .failure(exception):
                if !exception.isEqual(to: .Networking.Database.noValueExists) {
                    Logger.log(exception)
                }
            }
        }

        /* MARK: UserSessionService Setup */

        // User resolution likely completed during the metadata + update + cache gates above.
        switch await resolveCurrentUserResult {
        case .success:
            initializationProgress += 0.2

            guard let currentUser = clientSession.user.currentUser else {
                return .init(
                    "Failed to resolve current user.",
                    metadata: .init(sender: self)
                )
            }

            /* MARK: Last Sign In Date Update */

            // Must complete before the Firebase observer starts (post-splash),
            // otherwise the observer sees the timestamp change and triggers sign-out.
            if !RuntimeStorage.updatedLastSignInDate {
                if let exception = await currentUser.updateLastSignedInDate() {
                    return exception
                } else {
                    RuntimeStorage.store(true, as: .updatedLastSignInDate)
                }
            }

            Networking.config.setIsEnhancedDialogTranslationEnabled(
                currentUser.aiEnhancedTranslationsEnabled
            )

            checkPrevaricationMode(currentUser.phoneNumber)
            loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

            /* MARK: Contact Pair Archive + Temporary Cache Population */

            if let exception = await ContactService.populateValuesIfNeeded() {
                Logger.log(exception)
            }

            @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
            if (currentUser.conversationIDs ?? []).count > 20,
               (conversationArchive ?? []).isEmpty {
                let database = LockIsolated<any DatabaseDelegate>(networking.database)
                if let exception = await database.wrappedValue.populateTemporaryCaches() {
                    Logger.log(exception)
                }
            }

            /* MARK: Conversation Resolution */

            if let exception = await currentUser.setConversations() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
                return exception
            }

            initializationProgress = 1

            /* MARK: Post-launch Maintenance */

            Task { [weak self] in
                guard let self else { return }

                let pushTokenService = LockIsolated<PushTokenService>(services.pushToken)
                if Networking.config.environment != .staging,
                   let exception = await pushTokenService
                   .wrappedValue
                   .prunePushTokensForCurrentUser() {
                    Logger.log(
                        exception,
                        with: .toastInPrerelease
                    )
                }

                if let exception = await TypingIndicatorService
                    .resetTypingIndicatorStatusForCurrentUser() {
                    Logger.log(
                        exception,
                        with: .toastInPrerelease
                    )
                }

                if let exception = await services
                    .notification
                    .setBadgeNumber(currentUser.calculateBadgeNumber()) {
                    Logger.log(
                        exception,
                        with: .toastInPrerelease
                    )
                }

                if let exception = await services
                    .penPals
                    .updateSharingDataForKnownUsers() {
                    Logger.log(
                        exception,
                        with: .toastInPrerelease
                    )
                }
            }

            return nil

        case let .failure(exception):
            guard !exception.isEqual(to: .currentUserIDNotSet) else {
                initializationProgress = 1
                return nil
            }

            return exception
        }
    }

    /// `.errorAlertDismissed`
    func performRetryHandler() async -> Exception? {
        func attemptDatabaseRepair() async -> Exception? {
            didAttemptDatabaseRepair = true
            loadingLabelText = "\(Localized(.repairingData).wrappedValue)..."

            guard let exception = await networking.integrityService.repairDatabase() else { return nil }
            if exception.isEqual(to: .updateRequired) {
                services.update.isForcedUpdateRequiredSubject.send(true)
                return nil
            }

            return exception
        }

        if let currentUserID = User.currentUserID,
           !didAttemptUserConversion {
            didAttemptUserConversion = true
            if let exception = await networking.userService.legacy.convertUser(id: currentUserID) {
                Logger.log(exception)
                return await attemptDatabaseRepair()
            }
        } else if !didAttemptDatabaseRepair {
            return await attemptDatabaseRepair()
        } else {
            Application.reset()
            didAttemptDatabaseRepair = false
        }

        return nil
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
            background: .init(uiColor: .init(hex: 0xF8F8F8)),
        ))

        ThemeService.setTheme(
            UITheme.prevaricationMode,
            checkStyle: false
        )
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
