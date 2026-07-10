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
    @Dependency(\.jsonEncoder) private var jsonEncoder: JSONEncoder

    // MARK: - Properties

    static let shared = SessionStoreInvalidationService()

    private var changeHandlerID: UUID?
    private var pendingConversationIDKeys = Set<String>()
    private var pendingUserIDs = Set<String>()

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    func startObserving() {
        guard changeHandlerID == nil else { return }
        changeHandlerID = SessionStore.addChangeHandler { [weak self] change in
            self?.handleChange(change)
        }
    }
}

private extension SessionStoreInvalidationService {
    // MARK: - Types

    enum TaskID: String {
        case chatPageReload
        case conversationCellViewData
        case conversationCellViewDataTargeted
        case notificationExtensionNameMap
        case readReceipt
        case user
        case userDisplayName
    }

    // MARK: - Methods

    func handleChange(_ change: SessionStoreChange) {
        switch change {
        case let .conversations(upsertedIDKeys, removedIDKeys):
            handleConversationsChange(
                upsertedIDKeys: upsertedIDKeys,
                removedIDKeys: removedIDKeys
            )

        case .messages:
            handleMessagesChange()

        case let .users(upsertedIDs):
            handleUsersChange(upsertedIDs: upsertedIDs)
        }

        reloadChatPageIfNeeded(for: change)
    }

    func handleConversationsChange(
        upsertedIDKeys: Set<String>,
        removedIDKeys: Set<String>
    ) {
        let affectedIDKeys = upsertedIDKeys.union(removedIDKeys)
        guard !affectedIDKeys.isEmpty else { return }

        pendingConversationIDKeys.formUnion(affectedIDKeys)
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.conversationCellViewDataTargeted.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self else { return }

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

    func handleMessagesChange() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.conversationCellViewData.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor in
            ConversationCellViewDataCache.clearCache()
        }

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.readReceipt.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor in
            ReadReceiptCache.clearCache()
        }
    }

    func handleUsersChange(upsertedIDs: Set<String>) {
        pendingUserIDs.formUnion(upsertedIDs)

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.conversationCellViewData.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor in
            ConversationCellViewDataCache.clearCache()
        }

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.user.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor in
            UserCache.clearCache()
        }

        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.userDisplayName.rawValue)",
            delay: .milliseconds(250)
        ) { @MainActor [weak self] in
            guard let self else { return }

            let ids = pendingUserIDs
            pendingUserIDs = []
            UserDisplayNameCache.removeValues(forUserIDs: ids)
        }
    }

    func persistValuesForNotificationExtension() {
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

    func reloadChatPageIfNeeded(for change: SessionStoreChange) {
        guard chatPageState.isPresented,
              let currentConversation = clientSession
              .conversation
              .currentConversation else { return }

        let shouldReload: Bool = switch change {
        case let .conversations(upsertedIDKeys, _):
            upsertedIDKeys.contains(currentConversation.id.key)

        case let .messages(upsertedIDs):
            !Set(currentConversation.messageIDs)
                .isDisjoint(with: upsertedIDs)

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
