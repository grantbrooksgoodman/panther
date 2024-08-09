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

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class SplashPageViewService: ObservableObject {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.networking.services) private var networkServices: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    // Bool
    private var didAttemptDatabaseRepair = false
    private var didAttemptUserConversion = false
    @Persistent(.didClearCaches) private var didClearCaches: Bool?
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

    public var shouldShowLoadingLabel: Bool {
        didAttemptDatabaseRepair ||
            (didClearCaches ?? false) ||
            didSurpassQuickLoadTimeoutDuration
    }

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    @MainActor
    public func initializeBundle() async -> Exception? {
        /* MARK: Service Setup */

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
        alertKitConfig.registerTranslationDelegate(networkServices.translation)

        guard build.isOnline else {
            if let exception = userSession.setOfflineCurrentUser() {
                Logger.log(exception)
            }

            initializationProgress = 1

            guard let currentUser = userSession.currentUser else { return nil }
            core.utils.setLanguageCode(currentUser.languageCode)
            return nil
        }

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

                    var defaultsKeysToKeep = UserDefaultsKeyDomain.permanentKeys
                    defaultsKeysToKeep.append(.app(.userSessionService(.currentUserID)))
                    defaults.reset(keeping: defaultsKeysToKeep)

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
            if let exception = await networkServices.translation.archiver.addRecentlyUploadedLocalizedTranslationsToLocalArchive() {
                Logger.log(exception)
            } else {
                initializationProgress += 0.01
            }
        }

        /* MARK: MetadataService Setup */

        if let exception = await services.metadata.resolveValues() {
            return exception
        }

        initializationProgress += 0.01

        /* MARK: ReviewService Setup */

        services.review.incrementAppOpenCount()

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()
        if let exception = await services.update.promptToUpdateIfNeeded() {
            return exception
        }

        initializationProgress += 0.01

        /* MARK: UserSessionService Setup */

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case .success:
            initializationProgress += 0.2

            guard let currentUser = userSession.currentUser else {
                return .init("Failed to set current user.", metadata: [self, #file, #function, #line])
            }

            core.utils.setLanguageCode(currentUser.languageCode)
            loadingLabelText = "\(Localized(.loadingData).wrappedValue)..."

            if let exception = await currentUser.setConversations() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await userSession.resetTypingIndicatorStatus() {
                return exception
            }

            initializationProgress += 0.2

            if let exception = await services.notification.modifyBadgeNumber(.set(to: currentUser.badgeNumber)) {
                return exception
            }

            var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 4 == 0 }
            let mustUpdateContactPairArchive = ContactPairArchiveStatus.needsUpdate || (didClearCaches ?? false)
            didClearCaches = nil

            if !mustUpdateContactPairArchive {
                guard randomBool, randomBool, randomBool else {
                    initializationProgress = 1
                    return nil
                }
            }

            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: mustUpdateContactPairArchive || (randomBool && randomBool)),
               !exception.isEqual(to: .notAuthorizedForContacts) {
                return exception
            }

            ContactPairArchiveStatus.setNeedsUpdate(false)

            if let exception = await networkServices.translation.archiver.addRecentlyUploadedLocalizedTranslationsToLocalArchive() {
                Logger.log(exception)
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
            return await networkServices.integrity.repairDatabase()
        }

        @Persistent(.currentUserID) var currentUserID: String?

        if let currentUserID,
           !didAttemptUserConversion {
            didAttemptUserConversion = true
            if let exception = await networkServices.user.legacy.convertUser(id: currentUserID) {
                guard !exception.isEqual(to: .userDoesNotNeedConversion) else { return await attemptDatabaseRepair() }
                return exception
            }
        } else if !didAttemptDatabaseRepair {
            return await attemptDatabaseRepair()
        } else {
            core.utils.clearCaches()
            core.utils.eraseDocumentsDirectory()
            core.utils.eraseTemporaryDirectory()

            defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)
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
}

// swiftlint:enable cyclomatic_complexity function_body_length
