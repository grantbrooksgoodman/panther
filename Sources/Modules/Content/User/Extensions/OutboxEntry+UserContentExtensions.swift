//
//  OutboxEntry+UserContentExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import Translator

extension OutboxEntry {
    // MARK: - Methods

    func asDisplayMessage() -> Message {
        @Dependency(\.clientSession.entity.user.currentUser) var currentUser: User?
        let languageCode = currentUser?.languageCode ?? "en"
        let selfTranslationPair = LanguagePair(
            from: languageCode,
            to: languageCode
        )

        switch payload {
        case let .audio(inputFileName):
            let outbox = MessageOutboxService.shared
            let fileURL = outbox.payloadFileURL(forFileName: inputFileName)
            let audioFile = AudioFile(
                fileURL,
                name: inputFileName,
                fileExtension: .m4a,
                contentDuration: 0
            )

            let mockTranslation = Translation(
                input: .init(""),
                output: "",
                languagePair: selfTranslationPair
            )

            let audioReference = AudioMessageReference(
                translation: mockTranslation,
                original: audioFile,
                translated: audioFile,
                translatedDirectoryPath: ""
            )

            return .init(
                id,
                fromAccountID: fromAccountID,
                contentType: .audio(.m4a),
                richContent: .audio([audioReference]),
                translationReferences: [mockTranslation.reference],
                translations: [mockTranslation],
                readReceipts: nil,
                sentDate: createdDate
            )

        case let .media(fileName, fileExtension):
            let outbox = MessageOutboxService.shared
            let fileURL = outbox.payloadFileURL(forFileName: fileName)
            let relativePath = "outbox/\(fileName)"
            let mediaFile = MediaFile(
                relativePath,
                name: fileName,
                fileExtension: fileExtension
            )

            return .init(
                id,
                fromAccountID: fromAccountID,
                contentType: .media(
                    id: mediaFile.encodedHash.shortened,
                    extension: fileExtension
                ),
                richContent: .media(mediaFile),
                translationReferences: nil,
                translations: nil,
                readReceipts: nil,
                sentDate: createdDate
            )

        case let .text(string):
            let mockTranslation = Translation(
                input: .init(string.trimmingTrailingWhitespace),
                output: string.trimmingTrailingWhitespace,
                languagePair: selfTranslationPair
            )

            return .init(
                id,
                fromAccountID: fromAccountID,
                contentType: .text,
                richContent: nil,
                translationReferences: [mockTranslation.reference],
                translations: [mockTranslation],
                readReceipts: nil,
                sentDate: createdDate
            )
        }
    }
}
