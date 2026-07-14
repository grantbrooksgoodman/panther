//
//  SchemaMigration.swift
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem

/// Tracks which records were decoded from a legacy
/// server format and need an opportunistic rewrite to
/// the current schema.
///
/// Decoders call the `flag*` methods when they encounter
/// a legacy-format node. The migration service reads
/// these signals to decide which records to rewrite.
enum SchemaMigration {
    // MARK: - Properties

    private static let _legacyBlockedUserIDsUserIDs = LockIsolated(Set<String>())
    private static let _legacyConversationIDUserIDs = LockIsolated(Set<String>())
    private static let _legacyMessageIndexConversationIDKeys = LockIsolated(Set<String>())
    private static let _legacyParticipantConversationIDKeys = LockIsolated(Set<String>())
    private static let _legacyPushTokenUserIDs = LockIsolated(Set<String>())

    // MARK: - Computed Properties

    static var legacyBlockedUserIDsUserIDs: Set<String> {
        _legacyBlockedUserIDsUserIDs.wrappedValue
    }

    static var legacyConversationIDUserIDs: Set<String> {
        _legacyConversationIDUserIDs.wrappedValue
    }

    static var legacyMessageIndexConversationIDKeys: Set<String> {
        _legacyMessageIndexConversationIDKeys.wrappedValue
    }

    static var legacyParticipantConversationIDKeys: Set<String> {
        _legacyParticipantConversationIDKeys.wrappedValue
    }

    static var legacyPushTokenUserIDs: Set<String> {
        _legacyPushTokenUserIDs.wrappedValue
    }

    // MARK: - Methods

    static func flagLegacyBlockedUserIDs(userID: String) {
        _legacyBlockedUserIDsUserIDs.projectedValue.withValue { $0.insert(userID) }
    }

    static func flagLegacyConversationIDs(userID: String) {
        _legacyConversationIDUserIDs.projectedValue.withValue { $0.insert(userID) }
    }

    static func flagLegacyMessageIndex(conversationIDKey: String) {
        _legacyMessageIndexConversationIDKeys.projectedValue.withValue { $0.insert(conversationIDKey) }
    }

    static func flagLegacyParticipants(conversationIDKey: String) {
        _legacyParticipantConversationIDKeys.projectedValue.withValue { $0.insert(conversationIDKey) }
    }

    static func flagLegacyPushTokens(userID: String) {
        _legacyPushTokenUserIDs.projectedValue.withValue { $0.insert(userID) }
    }

    static func unflag(userID: String) {
        _legacyBlockedUserIDsUserIDs.projectedValue.withValue { $0.remove(userID) }
        _legacyConversationIDUserIDs.projectedValue.withValue { $0.remove(userID) }
        _legacyPushTokenUserIDs.projectedValue.withValue { $0.remove(userID) }
    }

    static func unflag(conversationIDKey: String) {
        _legacyMessageIndexConversationIDKeys.projectedValue.withValue { $0.remove(conversationIDKey) }
        _legacyParticipantConversationIDKeys.projectedValue.withValue { $0.remove(conversationIDKey) }
    }
}
