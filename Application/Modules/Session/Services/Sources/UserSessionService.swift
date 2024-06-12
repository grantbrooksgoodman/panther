//
//  UserSessionService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import CoreArchitecture
import FirebaseDatabase

// swiftlint:disable:next type_body_length
public final class UserSessionService {
    // MARK: - Dependencies

    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.clientSession.conversation) private var conversationSession: ConversationSessionService
    @Dependency(\.firebaseDatabase) private var firebaseDatabase: DatabaseReference
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue
    @Dependency(\.networking) private var networking: Networking
    @Dependency(\.commonServices.notification) private var notificationService: NotificationService

    // MARK: - Properties

    public private(set) var currentUser: User?
    @Persistent(.currentUserID) private var currentUserID: String?
    private var isUpdatingCurrentUser = false

    // MARK: - Computed Properties

    private var currentUserDatabaseReference: DatabaseReference? {
        guard let currentUser else { return nil }
        return firebaseDatabase.child(
            "\(networking.config.environment.shortString)/\(networking.config.paths.users)/\(currentUser.id)"
        )
    }

    // MARK: - Object Lifecycle

    deinit {
        if let exception = stopObservingCurrentUserChanges() {
            Logger.log(exception, domain: .userSession)
        }
    }

    // MARK: - Set Current User

    public func setCurrentUser(_ cacheStrategy: CacheStrategy = .returnCacheOnFailure) async -> Callback<User, Exception> {
        guard let currentUserID else {
            return .failure(.init("Current user ID has not been set.", metadata: [self, #file, #function, #line]))
        }

        if cacheStrategy == .returnCacheFirst,
           let currentUser,
           currentUser.id == currentUserID {
            return .success(currentUser)
        }

        isUpdatingCurrentUser = true

        let getUserResult = await networking.services.user.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            // FIXME: Seeing data races occur here. Fixed using mainQueue.sync for now.
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            isUpdatingCurrentUser = false
            return .success(user)

        case let .failure(exception):
            isUpdatingCurrentUser = false

            if cacheStrategy == .returnCacheOnFailure,
               let currentUser,
               currentUser.id == currentUserID {
                return .success(currentUser)
            }

            return .failure(exception)
        }
    }

    // MARK: - Current User Observation

    public func startObservingCurrentUserChanges() {
        guard let currentUserDatabaseReference else { return }
        currentUserDatabaseReference.removeAllObservers()

        Logger.log(
            "Started observing current user changes.",
            domain: .userSession,
            metadata: [self, #file, #function, #line]
        )

        currentUserDatabaseReference.observe(.value) { snapshot in
            guard let currentUser = self.currentUser else { return }
            guard let dictionary = snapshot.value as? [String: Any] else {
                Logger.log(
                    .init(
                        "Failed to typecast values to dictionary.",
                        metadata: [self, #file, #function, #line]
                    ),
                    domain: .userSession
                )
                return
            }

            func updateCurrentUser() {
                Task {
                    if let exception = await self.updateCurrentUser() {
                        Logger.log(exception, domain: .user)
                    }
                }
            }

            guard let updatedConversationIDStrings = dictionary[User.SerializationKeys.conversationIDs.rawValue] as? [String] else { return }
            guard let currentConversationIDStrings = currentUser.conversationIDs?.map(\.encoded) else {
                updateCurrentUser()
                return
            }

            guard currentConversationIDStrings.sorted() != updatedConversationIDStrings.sorted() else {
                Logger.log(
                    "Skipping current user update as conversation ID values do not appear to have changed.",
                    domain: .user,
                    metadata: [self, #file, #function, #line]
                )
                return
            }

            // Remove deleted conversations
            for id in currentConversationIDStrings where !updatedConversationIDStrings.contains(id) {
                self.networking.services.conversation.archive.removeValue(idKey: id)
            }

            updateCurrentUser()
        } withCancel: { error in
            Logger.log(.init(error, metadata: [self, #file, #function, #line]), domain: .userSession)
        }
    }

    @discardableResult
    public func stopObservingCurrentUserChanges() -> Exception? {
        guard let currentUserDatabaseReference else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        Logger.log(
            "Stopped observing current user changes.",
            domain: .userSession,
            metadata: [self, #file, #function, #line]
        )

        currentUserDatabaseReference.removeAllObservers()
        return nil
    }

    // MARK: - Delete Account

    public func deleteAccount() async -> Exception? {
        guard let currentUserID else {
            return .init("Current user ID has not been set.", metadata: [self, #file, #function, #line])
        }

        func deleteUser() async -> Exception? {
            if let exception = await networking.database.setValue(NSNull(), forKey: "\(networking.config.paths.users)/\(currentUserID)") {
                return exception
            }

            let getValuesResult = await networking.database.getValues(at: networking.config.paths.deletedUsers)

            switch getValuesResult {
            case let .success(values):
                guard var array = values as? [String] else {
                    return .init("Failed to typecast values to array.", metadata: [self, #file, #function, #line])
                }

                array.append(currentUserID)
                array = array.filter { $0 != .bangQualifiedEmpty }.unique

                if let exception = await networking.database.setValue(array, forKey: networking.config.paths.deletedUsers) {
                    return exception
                }

                return nil

            case let .failure(exception):
                return exception
            }
        }

        let getUserResult = await networking.services.user.getUser(id: currentUserID)

        switch getUserResult {
        case let .success(user):
            let userNumberHashesPath = "\(networking.config.paths.userNumberHashes)/\(user.phoneNumber.nationalNumberString.digits.encodedHash)"
            let getValuesResult = await networking.database.getValues(at: userNumberHashesPath)

            switch getValuesResult {
            case let .success(values):
                guard var array = values as? [String] else {
                    return .init("Failed to typecast values to array.", metadata: [self, #file, #function, #line])
                }

                array = array.filter { $0 != currentUserID }.unique

                if let exception = await networking.database.setValue(
                    array.isBangQualifiedEmpty ? NSNull() : array,
                    forKey: userNumberHashesPath
                ) {
                    return exception
                }

            case let .failure(exception):
                return exception
            }

            if let exception = await user.setConversations() {
                return exception
            }

            guard let conversations = user.conversations else { return await deleteUser() }

            for conversation in conversations {
                if let exception = await conversationSession.deleteConversation(conversation, forced: true) {
                    return exception
                }
            }

            return await deleteUser()

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Get Users for Conversation

    public func getUsers(conversation: Conversation) async -> Callback<[User], Exception> {
        let commonParams = ["ConversationID": conversation.id.encoded]

        let userIDs = conversation.participants.map(\.userID).filter { $0 != currentUserID }
        guard !userIDs.isBangQualifiedEmpty else {
            let exception = Exception("No participants for this conversation.", metadata: [self, #file, #function, #line])
            return .failure(exception.appending(extraParams: commonParams))
        }

        let getUsersResult = await networking.services.user.getUsers(ids: userIDs)

        switch getUsersResult {
        case let .success(users):
            guard !users.isEmpty,
                  users.count == userIDs.count else {
                let exception = Exception("Mismatched ratio returned.", metadata: [self, #file, #function, #line])
                return .failure(exception.appending(extraParams: commonParams))
            }

            return .success(users)

        case let .failure(exception):
            return .failure(exception.appending(extraParams: commonParams))
        }
    }

    // MARK: - Push Tokens

    @discardableResult
    public func resetPushTokens() async -> Exception? {
        notificationService.setPushToken(nil)

        guard currentUser?.pushTokens != nil else {
            return .init("Push token has not been set.", metadata: [self, #file, #function, #line])
        }

        let updateValueResult = await currentUser?.updateValue(Array.bangQualifiedEmpty, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            return nil

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }
    }

    @discardableResult
    public func updatePushTokens() async -> Exception? {
        guard let pushToken = notificationService.pushToken else {
            return .init("Push token has not been set.", metadata: [self, #file, #function, #line])
        }

        var pushTokens = currentUser?.pushTokens ?? []
        guard !pushTokens.contains(pushToken) else {
            return .init("Push tokens already up to date.", metadata: [self, #file, #function, #line])
        }

        pushTokens.append(pushToken)
        let updateValueResult = await currentUser?.updateValue(pushTokens.unique, forKey: .pushTokens)

        switch updateValueResult {
        case let .success(user):
            mainQueue.sync {
                currentUser = user
                self.currentUserID = user.id
            }
            return nil

        case let .failure(exception):
            return exception

        case .none:
            return nil
        }
    }

    // MARK: - Reset Typing Indicator Status

    public func resetTypingIndicatorStatus() async -> Exception? {
        guard let currentUser else {
            return .init("Current user has not been set.", metadata: [self, #file, #function, #line])
        }

        guard let conversations = currentUser
            .conversations?
            .filter({ $0.participants.first(where: { $0.userID == currentUser.id })?.isTyping ?? false }) else { return nil }

        for conversation in conversations {
            guard let currentUserParticipant = conversation.participants.first(where: { $0.userID == currentUser.id }) else { continue }

            var newParticipants = conversation.participants.filter { $0 != currentUserParticipant }
            newParticipants.append(.init(
                userID: currentUserParticipant.userID,
                hasDeletedConversation: currentUserParticipant.hasDeletedConversation,
                isTyping: false
            ))

            let updateValueResult = await conversation.updateValue(newParticipants, forKey: .participants)

            switch updateValueResult {
            case let .failure(exception):
                Logger.log(exception)

            default: ()
            }
        }

        return nil
    }

    // MARK: - Auxiliary

    private func updateCurrentUser() async -> Exception? {
        guard !isUpdatingCurrentUser else {
            Logger.log(
                "Skipping current user update because an update is already occurring.",
                domain: .userSession,
                metadata: [self, #file, #function, #line]
            )
            return nil
        }

        isUpdatingCurrentUser = true
        let setCurrentUserResult = await setCurrentUser()

        switch setCurrentUserResult {
        case .success:
            Logger.log(
                "Updated current user.",
                domain: .userSession,
                metadata: [self, #file, #function, #line]
            )

            Observables.updatedCurrentUser.trigger()
            chatPageState.setIsWaitingToUpdateConversations(chatPageState.isPresented)

            isUpdatingCurrentUser = false
            return nil

        case let .failure(exception):
            isUpdatingCurrentUser = false
            return exception
        }
    }
}
