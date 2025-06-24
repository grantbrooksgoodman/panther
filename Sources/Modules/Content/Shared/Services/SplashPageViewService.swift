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

public final class SplashPageViewService: ObservableObject {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    // Bool
    private var didAttemptDatabaseRepair = false
    private var didAttemptUserConversion = false
    private var didSurpassQuickLoadTimeoutDuration = false

    // Other
    @Published
    public var initializationProgress: CGFloat = 0 {
        didSet {
            guard initializationProgress == 1 else { return }
            core.gcd.after(.seconds(2)) { self.initializationProgress = 0 }
        }
    }

    @Published
    public private(set) var loadingLabelText = ""

    private var initializationStartDate = Date(timeIntervalSince1970: 0)

    // MARK: - Computed Properties

    public var shouldShowLoadingLabel: Bool { didAttemptDatabaseRepair || didSurpassQuickLoadTimeoutDuration }

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    @MainActor
    public func initializeBundle() async -> Exception? {
        /* MARK: Service Setup */

        if UIApplication.isBeingDebugged,
           UIApplication.isCompiledForV26OrLater {
            try? await Task.sleep(for: .seconds(5))
        }

        didSurpassQuickLoadTimeoutDuration = false
        initializationProgress = initializationProgress == 1 ? 0 : initializationProgress
        initializationStartDate = .now
        loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

        _ = Timeout(after: .seconds(3)) {
            guard self.initializationProgress <= 0.5 else { return }
            self.didSurpassQuickLoadTimeoutDuration = true
        }

        /* MARK: AKCore Delegate Setup */

        alertKitConfig.registerReportDelegate(ErrorReportingService())
        alertKitConfig.registerTranslationDelegate(networking.hostedTranslation)

        /* MARK: Offline User Setup */

        guard build.isOnline else {
            if let exception = userSession.setOfflineCurrentUser() {
                Logger.log(exception)
            }

            initializationProgress = 1

            guard let currentUser = userSession.currentUser else { return nil }
            core.utils.setLanguageCode(currentUser.languageCode)
            return nil
        }

        /* MARK: Language Code Resolution */

        if let exception = await userSession.resolveAndSetLanguageCode() {
            Logger.log(exception)
        }

        initializationProgress += 0.01

        /* MARK: MetadataService Setup */

        if let exception = await services.metadata.resolveValues() {
            return exception
        }

        initializationProgress += 0.01

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()
        if let exception = await services.update.promptToUpdateIfNeeded() {
            return exception
        }

        initializationProgress += 0.01

        /* MARK: Logger Setup */

        Logger.setReportsErrorsAutomatically(true)

        /* MARK: Cache Setup */

        @Persistent(.currentUserID) var currentUserID: String?

        if let currentUserID {
            let cacheStatusResult = await services.remoteCache.cacheStatus(userID: currentUserID)
            initializationProgress += 0.01

            switch cacheStatusResult {
            case let .success(cacheStatus):
                if cacheStatus == .invalid {
                    core.utils.clearCaches()
                    core.utils.eraseDocumentsDirectory()
                    core.utils.eraseTemporaryDirectory()

                    defaults.reset(preserving: .permanentAndSubsystemKeys(plus: [.userSessionService(.currentUserID)]))

                    if let exception = await services.remoteCache.setCacheStatus(.valid, userID: currentUserID) {
                        Logger.log(exception)
                    }
                }

            case let .failure(exception):
                Logger.log(exception)
            }
        }

        /* MARK: HostedTranslationArchiver Setup */

        if currentUserID == nil {
            if let exception = await networking.hostedTranslation.addRecentlyUploadedLocalizedTranslationsToLocalArchive() {
                Logger.log(exception)
            } else {
                initializationProgress += 0.01
            }
        }

        /* MARK: ReviewService Setup */

        services.review.incrementAppOpenCount()

        /* MARK: UserSessionService Setup */

        @Persistent(.conversationArchive) var conversationArchive: [Conversation]?
        @Persistent(.init("translationArchive")) var translationArchive: [Translation]?

        let resolveCurrentUserResult = await userSession.resolveCurrentUser()

        switch resolveCurrentUserResult {
        case .success:
            initializationProgress += 0.1

            guard let currentUser = userSession.currentUser else {
                return .init("Failed to set current user.", metadata: [self, #file, #function, #line])
            }

            checkPrevaricationMode(currentUser.phoneNumber)
            core.utils.setLanguageCode(currentUser.languageCode)
            loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

            if ((currentUser.conversationIDs ?? []).count > 3 && (conversationArchive ?? []).isEmpty) || (translationArchive ?? []).isEmpty {
                if let exception = await networking.database.populateTemporaryCaches() {
                    Logger.log(exception)
                }

                // Allow temporary cache population to settle before moving on.
                try? await Task.sleep(for: .milliseconds(500))

                if let exception = await services.pushToken.prunePushTokensForCurrentUser() {
                    Logger.log(exception)
                }
            }

            if let exception = await currentUser.setConversations() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await TypingIndicatorService.resetTypingIndicatorStatusForCurrentUser() {
                return exception
            }

            if let exception = await services.notification.setBadgeNumber(currentUser.calculateBadgeNumber()) {
                return exception
            }

            if let exception = await services.penPals.updateSharingDataForKnownUsers() {
                return exception
            }

            initializationProgress = 1
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
    public func performRetryHandler() async -> Exception? {
        func attemptDatabaseRepair() async -> Exception? {
            didAttemptDatabaseRepair = true
            loadingLabelText = "\(Localized(.repairingData).wrappedValue)..."
            return await networking.integrityService.repairDatabase()
        }

        @Persistent(.currentUserID) var currentUserID: String?

        if let currentUserID,
           !didAttemptUserConversion {
            didAttemptUserConversion = true
            if let exception = await networking.userService.legacy.convertUser(id: currentUserID) {
                Logger.log(exception)
                return await attemptDatabaseRepair()
            }
        } else if !didAttemptDatabaseRepair {
            return await attemptDatabaseRepair()
        } else {
            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            defaults.reset()
            didAttemptDatabaseRepair = false
        }

        return nil
    }

    /// `.initializedBundle`
    public func presentErrorAlert(_ exception: Exception) async {
        let mockGenericException: Exception = .init(metadata: [self, #file, #function, #line])
        let mockTimedOutException: Exception = .timedOut([self, #file, #function, #line])

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
        ThemeService.setTheme(
            UITheme.prevaricationMode,
            checkStyle: false
        )
    }
}

private extension UIApplication {
    static var isBeingDebugged: Bool {
        let mib: [Int32] = [
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_PID,
            getpid(),
        ]

        let mibCount = UInt32(mib.count)

        var info = kinfo_proc()
        var infoSize = MemoryLayout<kinfo_proc>.stride

        let result: Int32 = mib.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return -1 }
            return sysctl(
                UnsafeMutablePointer<Int32>(mutating: base),
                mibCount,
                &info,
                &infoSize,
                nil,
                0
            )
        }

        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    static var isCompiledForV26OrLater: Bool {
        #if compiler(>=6.2)
        return true
        #else
        return false
        #endif
    }
}

// swiftlint:enable cyclomatic_complexity function_body_length
