//
//  SplashPageViewService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/12/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import AlertKit
import CoreArchitecture

public final class SplashPageViewService {
    // MARK: - Dependencies

    @Dependency(\.alertKitCore) private var akCore: AKCore
    @Dependency(\.build) private var build: Build
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.userDefaults) private var defaults: UserDefaults
    @Dependency(\.networking.services) private var networkServices: NetworkServices
    @Dependency(\.onboardingService) private var onboardingService: OnboardingService
    @Dependency(\.commonServices) private var services: CommonServices
    @Dependency(\.clientSession.user) private var userSession: UserSessionService

    // MARK: - Properties

    private var didAttemptDatabaseRepair = false
    private var didAttemptUserConversion = false

    // MARK: - Methods

    /// `.viewAppeared`,
    /// `.errorAlertDismissed`
    public func initializeBundle() async -> Exception? {
        /* MARK: AKCore Delegate Setup */

        akCore.register(reportDelegate: ErrorReportingService())
        akCore.register(translationDelegate: networkServices.translation)

        guard build.isOnline else {
            if let exception = userSession.setOfflineCurrentUser() {
                Logger.log(exception)
            }

            guard let currentUser = userSession.currentUser else { return nil }
            akCore.setLanguageCode(currentUser.languageCode)
            RuntimeStorage.store(currentUser.languageCode, as: .languageCode)
            return nil
        }

        /* MARK: Cache Setup */

        @Persistent(.currentUserID) var currentUserID: String?

        if let userID = currentUserID {
            let cacheStatusResult = await services.remoteCache.cacheStatus(userID: userID)

            switch cacheStatusResult {
            case let .success(cacheStatus):
                if cacheStatus == .invalid {
                    coreUtilities.clearCaches()
                    coreUtilities.eraseDocumentsDirectory()
                    coreUtilities.eraseTemporaryDirectory()

                    var defaultsKeysToKeep = UserDefaultsKeyDomain.permanentKeys
                    defaultsKeysToKeep.append(.app(.userSessionService(.currentUserID)))
                    defaults.reset(keeping: defaultsKeysToKeep)

                    if let exception = await services.remoteCache.setCacheStatus(.valid, userID: userID) {
                        Logger.log(exception)
                    }
                }

            case let .failure(exception):
                Logger.log(exception)
            }
        }

        /* MARK: HostedTranslationArchiver Setup */

        if currentUserID == nil,
           let exception = await networkServices.translation.archiver.addRecentlyUploadedLocalizedTranslationsToLocalArchive() {
            Logger.log(exception)
        }

        /* MARK: MetadataService Setup */

        if let exception = await services.metadata.resolveValues() {
            return exception
        }

        /* MARK: ReviewService Setup */

        services.review.incrementAppOpenCount()

        /* MARK: UpdateService Setup */

        services.update.incrementRelaunchCountIfNeeded()
        if let exception = await services.update.promptToUpdateIfNeeded() {
            return exception
        }

        /* MARK: UserSessionService Setup */

        let setCurrentUserResult = await userSession.setCurrentUser()

        switch setCurrentUserResult {
        case .success:
            guard let currentUser = userSession.currentUser else {
                return .init("Failed to set current user.", metadata: [self, #file, #function, #line])
            }

            akCore.setLanguageCode(currentUser.languageCode)
            RuntimeStorage.store(currentUser.languageCode, as: .languageCode)

            if let exception = await currentUser.setConversations() {
                return exception
            }

            if let exception = await currentUser.conversations?.visibleForCurrentUser.setUsers() {
                return exception
            }

            if let exception = await userSession.resetTypingIndicatorStatus() {
                return exception
            }

            if let exception = await services.notification.modifyBadgeNumber(.set(to: currentUser.badgeNumber)) {
                return exception
            }

            var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 4 == 0 }
            @Persistent(.didClearCaches) var didClearCaches: Bool?
            let mustUpdateContactPairArchive = ContactPairArchiveStatus.needsUpdate || (didClearCaches ?? false)
            didClearCaches = nil

            if !mustUpdateContactPairArchive {
                guard randomBool, randomBool, randomBool else { return nil }
            }

            if let exception = await services.contact.sync.syncContactPairArchive(forceUpdate: mustUpdateContactPairArchive || (randomBool && randomBool)),
               !exception.isEqual(to: .notAuthorizedForContacts) {
                return exception
            }

            ContactPairArchiveStatus.setNeedsUpdate(false)

            if let exception = await networkServices.translation.archiver.addRecentlyUploadedLocalizedTranslationsToLocalArchive() {
                Logger.log(exception)
            }

            return nil

        case let .failure(exception):
            guard !exception.isEqual(to: .currentUserIDNotSet) else { return nil }
            return exception
        }
    }

    /// `.errorAlertDismissed`
    public func performRetryHandler() async -> Exception? {
        func attemptDatabaseRepair() async -> Exception? {
            didAttemptDatabaseRepair = true
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
            coreUtilities.clearCaches()
            coreUtilities.eraseDocumentsDirectory()
            coreUtilities.eraseTemporaryDirectory()

            defaults.reset(keeping: UserDefaultsKeyDomain.permanentKeys)
        }

        return nil
    }

    /// `.initializedBundle`
    /// - Returns: An integer describing the selected action ID.
    public func presentErrorAlert(_ exception: Exception) async -> Int {
        let akError = AKError(exception)
        let mockGenericException = Exception(metadata: [self, #file, #function, #line])
        let mockTimedOutException = Exception.timedOut([self, #file, #function, #line])

        let notGenericDescription = akError.description != mockGenericException.userFacingDescriptor
        let notTimedOutDescription = akError.description != mockTimedOutException.userFacingDescriptor
        let hasUserFacingDescriptor = akError.extraParams?.keys.contains(Exception.CommonParamKeys.userFacingDescriptor.rawValue) ?? false

        let shouldTranslate = hasUserFacingDescriptor && notGenericDescription && notTimedOutDescription
        var translationOptionKeys: [AKTranslationOptionKey] = [build.isOnline ? .actions(indices: nil) : .none]
        if shouldTranslate,
           build.isOnline {
            translationOptionKeys = [.actions(indices: nil), .message]
        }

        let errorAlert = AKErrorAlert(
            error: akError,
            cancelButtonTitle: Localized(.tryAgain).wrappedValue,
            shouldTranslate: translationOptionKeys
        )

        return await errorAlert.present()
    }
}
