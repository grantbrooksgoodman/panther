//
//  StagedUserIdentity.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/// The identity of a predefined participant used to stage sample conversations during development.
///
/// Each identity is the single source of truth for a staged user's account ID, language, display
/// name, and phone number. The staging service resolves or creates accounts from these identities,
/// and Developer Mode lists them when switching perspective for screenshot capture.
struct StagedUserIdentity: Hashable {
    // MARK: - Properties

    /// The identity of the German-speaking staged participant.
    static let erikaMustermann = StagedUserIdentity(
        id: "staged_erika_mustermann",
        languageCode: "de",
        name: "Erika Mustermann",
        callingCode: "49",
        nationalNumber: "15123456789",
        regionCode: "DE"
    )

    /// The identity of the French-speaking staged participant.
    static let jeanDupont = StagedUserIdentity(
        id: "staged_jean_dupont",
        languageCode: "fr",
        name: "Jean Dupont",
        callingCode: "33",
        nationalNumber: "612345678",
        regionCode: "FR"
    )

    /// The identity of the English-speaking staged participant.
    static let johnAppleseed = StagedUserIdentity(
        id: "staged_john_appleseed",
        languageCode: "en",
        name: "John Appleseed",
        callingCode: "1",
        nationalNumber: "5555555555",
        regionCode: "US"
    )

    /// The identity of the Spanish-speaking staged participant.
    static let juanPerez = StagedUserIdentity(
        id: "staged_juan_perez",
        languageCode: "es",
        name: "Juan P\u{00E9}rez",
        callingCode: "34",
        nationalNumber: "612345678",
        regionCode: "ES"
    )

    /// The identity of the Italian-speaking staged participant.
    static let marioRossi = StagedUserIdentity(
        id: "staged_mario_rossi",
        languageCode: "it",
        name: "Mario Rossi",
        callingCode: "39",
        nationalNumber: "3123456789",
        regionCode: "IT"
    )

    /// The identity of the Russian-speaking staged participant.
    static let peterIvanov = StagedUserIdentity(
        id: "staged_peter_ivanov",
        languageCode: "ru",
        name: "Peter Ivanov",
        callingCode: "380",
        nationalNumber: "501234567",
        regionCode: "UA"
    )

    /// The identity of the Chinese-speaking staged participant.
    static let zhangShan = StagedUserIdentity(
        id: "staged_zhang_shan",
        languageCode: "zh",
        name: "Zhang Shan",
        callingCode: "886",
        nationalNumber: "912345678",
        regionCode: "TW"
    )

    /// Every staged participant identity, sorted by name.
    static let all: [StagedUserIdentity] = [
        erikaMustermann,
        jeanDupont,
        johnAppleseed,
        juanPerez,
        marioRossi,
        peterIvanov,
        zhangShan,
    ]

    /// The staged user's account ID.
    let id: String

    /// The code of the language the staged user speaks.
    let languageCode: String

    /// The staged user's display name.
    let name: String

    /// The staged user's phone number.
    let phoneNumber: PhoneNumber

    // MARK: - Methods

    /// Returns the identity of a twin participant speaking the given language.
    ///
    /// A twin stands in for a staged speaker of a language none of ``all`` speaks, so every
    /// language can capture the Beach Day conversation from a same-language perspective. Twins
    /// send no messages. Their phone numbers fall in the fictional 555-01XX range and are derived
    /// from the language code, so the same language always resolves to the same account.
    ///
    /// - Parameter languageCode: The code of the language the twin speaks.
    ///
    /// - Returns: The twin participant identity.
    static func twin(
        for languageCode: String
    ) -> StagedUserIdentity {
        let normalizedCode = String(
            languageCode
                .lowercased()
                .unicodeScalars
                .filter { ("a" ... "z").contains($0) }
                .prefix(2)
        )

        let lineNumber = normalizedCode
            .unicodeScalars
            .reduce(0) { partialResult, scalar in
                partialResult * 26 + Int(scalar.value - UnicodeScalar("a").value)
            }

        return .init(
            id: "staged_twin_\(normalizedCode)",
            languageCode: languageCode,
            name: "Twin",
            callingCode: "1",
            nationalNumber: "555555" + String(format: "%04d", lineNumber),
            regionCode: "US"
        )
    }

    // MARK: - Init

    private init(
        id: String,
        languageCode: String,
        name: String,
        callingCode: String,
        nationalNumber: String,
        regionCode: String
    ) {
        self.id = id
        self.languageCode = languageCode
        self.name = name
        phoneNumber = .init(
            callingCode: callingCode,
            nationalNumberString: nationalNumber,
            regionCode: regionCode,
            label: nil,
            internalFormattedString: nil
        )
    }
}
