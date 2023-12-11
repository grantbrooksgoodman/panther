//
//  Message+Serializable.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* 3rd-party */
import Redux
import Translator

extension Message: Serializable {
    // MARK: - Type Aliases

    public typealias T = Message
    private typealias Keys = SerializationKeys

    // MARK: - Types

    public enum SerializationKeys: String {
        case id
        case fromAccountID = "fromAccount"
        case hasAudioComponent
        case languagePair
        case translation = "translationReference"
        case readDate
        case sentDate
    }

    // MARK: - Properties

    public var encoded: [String: Any] {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter

        var readDateString = String.bangQualifiedEmpty
        if let readDate {
            readDateString = dateFormatter.string(from: readDate)
        }

        return [
            Keys.id.rawValue: id,
            Keys.fromAccountID.rawValue: fromAccountID,
            Keys.hasAudioComponent.rawValue: hasAudioComponent,
            Keys.languagePair.rawValue: languagePair.asString(),
            Keys.translation.rawValue: translation.serialized.key,
            Keys.readDate.rawValue: readDateString,
            Keys.sentDate.rawValue: dateFormatter.string(from: sentDate),
        ]
    }

    // MARK: - Methods

    public static func decode(from data: [String: Any]) async -> Callback<Message, Exception> {
        @Dependency(\.standardDateFormatter) var dateFormatter: DateFormatter
        @Dependency(\.networking.services) var networkServices: NetworkServices

        guard let id = data[Keys.id.rawValue] as? String,
              let fromAccountID = data[Keys.fromAccountID.rawValue] as? String,
              let hasAudioComponentString = data[Keys.hasAudioComponent.rawValue] as? String,
              hasAudioComponentString == "true" || hasAudioComponentString == "false",
              let languagePairString = data[Keys.languagePair.rawValue] as? String,
              let translationReference = data[Keys.translation.rawValue] as? String,
              let readDateString = data[Keys.readDate.rawValue] as? String,
              let sentDateString = data[Keys.sentDate.rawValue] as? String,
              let sentDate = dateFormatter.date(from: sentDateString),
              let languagePair: LanguagePair = .init(languagePairString) else {
            return .failure(.decodingFailed(data: data, [self, #file, #function, #line]))
        }

        let hasAudioComponent = hasAudioComponentString == "true" ? true : false

        var readDate: Date?
        if !readDateString.isBangQualifiedEmpty {
            readDate = dateFormatter.date(from: readDateString)
        }

        let findArchivedTranslationResult = await networkServices.translation.archiver.findArchivedTranslation(
            id: translationReference,
            languagePair: languagePair
        )

        func decodedMessage(_ translation: Translation) -> Message {
            .init(
                id,
                fromAccountID: fromAccountID,
                hasAudioComponent: hasAudioComponent,
                audioComponent: nil,
                languagePair: languagePair,
                translation: translation,
                readDate: readDate,
                sentDate: sentDate
            )
        }

        switch findArchivedTranslationResult {
        case let .success(translation):
            if hasAudioComponent {
                return await networkServices.message.audio.getAudioComponent(for: decodedMessage(translation))
            } else {
                return .success(decodedMessage(translation))
            }

        case let .failure(exception):
            return .failure(exception)
        }
    }
}
