//
//  SessionStoreInvalidationService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

@MainActor
final class SessionStoreInvalidationService {
    // MARK: - Dependencies

    @Dependency(\.appGroupDefaults) private var appGroupDefaults: UserDefaults
    @Dependency(\.chatPageStateService) private var chatPageState: ChatPageStateService
    @Dependency(\.chatPageViewService) private var chatPageViewService: ChatPageViewService
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit.utils) private var coreUtilities: CoreKit.Utilities
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder
    @Dependency(\.navigation) private var navigation: Navigation

    // MARK: - Properties

    fileprivate static let shared = SessionStoreInvalidationService()

    private var changeHandlerID: UUID?
    private var pendingConversationIDKeys = Set<String>()
    private var pendingUserIDs = Set<String>()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    func refreshNotificationExtensionNameMap() {
        persistValuesForNotificationExtension()
    }

    func startObserving() {
        guard changeHandlerID == nil else { return }
        changeHandlerID = SessionStore.addChangeHandler { [weak self] change in
            self?.handleChange(change)
        }
    }
}

private extension SessionStoreInvalidationService {
    // MARK: - Types

    private enum TaskID: String {
        case chatPageReload
        case conversationInvalidation
        case messageInvalidation
        case notificationExtensionNameMap
        case userInvalidation
    }

    // MARK: - Methods

    private func handleChange(_ change: SessionStoreChange) {
        switch change {
        case let .conversations(upsertedIDKeys, removedIDKeys):
            handleConversationsChange(
                upsertedIDKeys: upsertedIDKeys,
                removedIDKeys: removedIDKeys
            )

        case .messages:
            handleMessagesChange()

        case let .users(upsertedIDs, removedIDs):
            handleUsersChange(
                affectedIDs: upsertedIDs.union(removedIDs)
            )
        }

        reloadChatPageIfNeeded(for: change)
    }

    private func handleConversationsChange(
        upsertedIDKeys: Set<String>,
        removedIDKeys: Set<String>
    ) {
        let affectedIDKeys = upsertedIDKeys.union(removedIDKeys)
        guard !affectedIDKeys.isEmpty else { return }

        pendingConversationIDKeys.formUnion(affectedIDKeys)
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.conversationInvalidation.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self else { return }

            Logger.log(
                "Invalidating caches for conversation changes.",
                domain: .sessionStoreInvalidation,
                sender: self
            )

            let idKeys = pendingConversationIDKeys
            pendingConversationIDKeys = []

            for idKey in idKeys {
                ConversationCellViewDataCache.removeValues(
                    forConversationIDKey: idKey
                )
            }
        }

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.notificationExtensionNameMap.rawValue)",
            delay: .milliseconds(500)
        ) { @MainActor [weak self] in
            self?.persistValuesForNotificationExtension()
        }
    }

    private func handleMessagesChange() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.messageInvalidation.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self else { return }

            Logger.log(
                "Invalidating caches for message changes.",
                domain: .sessionStoreInvalidation,
                sender: self
            )

            coreUtilities.clearCaches([
                .conversationCellViewData,
                .readReceipt,
            ])
        }
    }

    private func handleUsersChange(affectedIDs: Set<String>) {
        pendingUserIDs.formUnion(affectedIDs)

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.userInvalidation.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self else { return }

            Logger.log(
                "Invalidating caches for user changes.",
                domain: .sessionStoreInvalidation,
                sender: self
            )

            let ids = pendingUserIDs
            pendingUserIDs = []

            coreUtilities.clearCaches([.conversationCellViewData])
            UserDisplayNameCache.removeValues(forUserIDs: ids)
        }
    }

    private func persistValuesForNotificationExtension() {
        let conversations = clientSession.store.conversations.values
        var conversationNameMap = [String: String]()

        for conversation in conversations where conversation.participants.count > 2 {
            guard let titleLabelText = ConversationCellViewData(conversation)?.titleLabelText,
                  !titleLabelText.isBangQualifiedEmpty else { continue }
            conversationNameMap[conversation.id.key] = titleLabelText
        }

        guard let encoded = try? jsonEncoder.encode(conversationNameMap) else { return }
        appGroupDefaults.set(
            encoded,
            forKey: NotificationExtensionConstants.conversationNameMapDefaultsKeyName
        )
    }

    private func reloadChatPageIfNeeded(for change: SessionStoreChange) {
        guard chatPageState.isPresented,
              let currentConversation = clientSession
              .conversation
              .currentConversation else { return }

        // Dismiss the chat page when the current conversation
        // is removed (e.g., deleted remotely by another
        // participant).

        // TODO: This doesn't work. Investigate this path.
        if case let .conversations(_, removedIDKeys) = change,
           removedIDKeys.contains(currentConversation.id.key) {
            navigation.navigate(to: .userContent(.stack([])))
            Toast.show(
                .init(
                    .banner(style: .info),
                    message: "This conversation is no longer available."
                ),
                translating: Toast.TranslationOptionKey.allCases
            )

            return
        }

        let shouldReload: Bool = switch change {
        case let .conversations(upsertedIDKeys, _):
            upsertedIDKeys.contains(currentConversation.id.key)

        case let .messages(upsertedIDs, removedIDs):
            !Set(currentConversation.messageIDs)
                .isDisjoint(with: upsertedIDs.union(removedIDs))

        case .users:
            false
        }

        guard shouldReload else { return }
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.chatPageReload.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            self?.chatPageViewService.reloadCollectionView()
        }
    }
}

// swiftlint:disable:next type_name
enum SessionStoreInvalidationServiceDependency: DependencyKey {
    static func resolve(_: DependencyValues) -> SessionStoreInvalidationService {
        // swiftformat:disable all
        @MainActorIsolated var sessionStoreInvalidationService = SessionStoreInvalidationService.shared
        return sessionStoreInvalidationService // swiftformat:enable all
    }
}

extension DependencyValues {
    var sessionStoreInvalidationService: SessionStoreInvalidationService {
        get { self[SessionStoreInvalidationServiceDependency.self] }
        set { self[SessionStoreInvalidationServiceDependency.self] = newValue }
    }
}
