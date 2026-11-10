//
//  ConversationStagingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem
import Networking
import Translator

/// The service that stages sample conversations during development.
struct ConversationStagingService {
    // MARK: - Dependencies

    @Dependency(\.currentCalendar) private var calendar: Calendar
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.mainBundle) private var mainBundle: Bundle
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.clientSession.store) private var sessionStore: SessionStore
    @Dependency(\.clientSession.entity.user) private var userSession: UserSessionService

    // MARK: - Properties

    @LockIsolated private var localizedTextCache: [String: [StagedText: String]] = [:]
    @Persistent(.stagedMainUserID) private var stagedMainUserID: String?
    @Persistent(.stagedTwinLanguageCode) private var stagedTwinLanguageCode: String?
    private let stagedUserService: StagedUserService = .shared

    // MARK: - Computed Properties

    /// The shared conversation staging service.
    static let shared = ConversationStagingService()

    private var isOnProperEnvironment: Bool {
        Networking.config.environment != .production
    }

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    /// Stages a set of sample conversations for the current user.
    ///
    /// This method deletes the current user's existing conversations
    /// and replaces them with predefined sample conversations. It is
    /// available outside the production environment only.
    ///
    /// - Throws: An `Exception` if called in the production
    ///   environment, if the existing conversations cannot be
    ///   deleted, or if staging fails.
    @MainActor // swiftlint:disable:next function_body_length
    func stageConversations() async throws(Exception) {
        guard isOnProperEnvironment else {
            throw Exception(
                "Cannot stage conversations in the Production environment.",
                metadata: .init(sender: self)
            )
        }

        do throws(Exception) {
            userSession.stopObservingCurrentUserChanges()
            core.ui.addOverlay(
                alpha: 0.5,
                activityIndicator: .largeWhite
            )

            // Resolve staged users before deleting anything, so a
            // resolution failure aborts without data loss.
            let users = try await resolveStagedUsers()
            try await core.utils.deleteConversations(
                .allForCurrentUser,
                showsOverlay: false
            )
            sessionStore.clearConversationArchive()
            ConversationCellViewDataCache.clearCache()

            // Compute dates.

            let today = Date.now
            guard let date936AM = calendar.date(
                bySettingHour: 9,
                minute: 36,
                second: 0,
                of: today
            ),
                let date941AM = calendar.date(
                    bySettingHour: 9,
                    minute: 41,
                    second: 0,
                    of: today
                ),
                let dateJan24 = DateComponents(
                    calendar: calendar,
                    year: 2025,
                    month: 1,
                    day: 24,
                    hour: 10
                ).date,
                let dateJun29 = DateComponents(
                    calendar: calendar,
                    year: 2025,
                    month: 6,
                    day: 29,
                    hour: 14
                ).date,
                let dateYesterday = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: calendar.startOfDay(for: today)
                )?.addingTimeInterval(43200) else {
                throw Exception(
                    "Failed to resolve dates.",
                    metadata: .init(sender: self)
                )
            }

            // Prepare media data.

            guard let imageData = UIImage(
                resource: .hello
            ).dataCompressed(toKB: 100),
                let conversationPhotoURL = mainBundle.url(
                    forResource: "image",
                    withExtension: "jpeg"
                ),
                let conversationPhotoData = UIImage(
                    contentsOfFile: conversationPhotoURL.path()
                )?.dataCompressed(toKB: 100),
                let videoURL = mainBundle.url(
                    forResource: "video",
                    withExtension: "mp4"
                ),
                let videoData = try? Data(contentsOf: videoURL) else {
                throw Exception(
                    "Failed to resolve required values.",
                    metadata: .init(sender: self)
                )
            }

            // Translate every staged text up front, concurrently,
            // so the conversations below never wait on translation.
            try await prefetchLocalizedTexts(for: users)

            // Stage conversations concurrently. Each writes only
            // its own conversation paths and per-conversation user
            // entries, so none can clobber another.
            let stagers: [() async throws(Exception) -> Void] = [
                // 1. Zhang Shan – image, 1/24/25.
                { () throws(Exception) in
                    let conversation = try await stageMediaConversation(
                        mediaData: imageData,
                        mediaFileExtension: .image(.jpeg),
                        mediaFileName: "staged_image",
                        from: users.zhangShan,
                        to: users.mainUser,
                        sentDate: dateJan24
                    )

                    try await conversation.updateReadDate(
                        for: conversation.messages ?? [],
                        userID: users.mainUser.id
                    )
                },
                // 2. Vacation Planning – text, 6/29/25.
                { () throws(Exception) in
                    let conversation = try await stageTextConversation(
                        .vacationPlanning,
                        from: users.mainUser,
                        to: [
                            users.erikaMustermann,
                            users.johnAppleseed,
                            users.juanPerez,
                            users.marioRossi,
                        ],
                        sentDate: dateJun29
                    )

                    _ = try await conversation.update(
                        \.metadata,
                        to: conversation.metadata.copyWith(
                            name: "Vacation Planning",
                            imageData: conversationPhotoData
                        )
                    )
                },
                // 3. Peter Ivanov – video, Yesterday.
                { () throws(Exception) in
                    let conversation = try await stageMediaConversation(
                        mediaData: videoData,
                        mediaFileExtension: .video(.mp4),
                        mediaFileName: "staged_video",
                        thumbnailData: imageData,
                        from: users.peterIvanov,
                        to: users.mainUser,
                        sentDate: dateYesterday
                    )

                    try await conversation.updateReadDate(
                        for: conversation.messages ?? [],
                        userID: users.mainUser.id
                    )
                },
                // 4. Mario Rossi + 2 – text, 9:36 AM.
                { () throws(Exception) in
                    let conversation = try await stageTextConversation(
                        text: "La partita inizia alle 18:00. Ci vediamo!",
                        from: users.marioRossi,
                        to: [
                            users.mainUser,
                            users.johnAppleseed,
                            users.zhangShan,
                        ],
                        sentDate: date936AM,
                        forcedOutputs: [
                            "en": "The game starts at 6pm. See you then!",
                        ]
                    )

                    try await conversation.updateReadDate(
                        for: conversation.messages ?? [],
                        userID: users.mainUser.id
                    )
                },
                // 5. Juan Pérez – audio, 9:41 AM, unread.
                { () throws(Exception) in
                    try await stageAudioConversation(
                        from: users.juanPerez,
                        to: users.mainUser,
                        sentDate: date941AM
                    )
                },
                // 6. Beach Day – group with image + text, 9:41 AM.
                { () throws(Exception) in
                    try await stageBeachDayConversation(
                        users: users,
                        sentDate: date941AM
                    )
                },
                // 7. App Store – 1:1 text + audio, 9:41 AM.
                { () throws(Exception) in
                    try await stageAppStoreConversation(
                        users: users,
                        sentDate: date941AM
                    )
                },
                // 8. View Original – 1:1 text, 9:41 AM.
                { () throws(Exception) in
                    try await stageViewOriginalConversation(
                        users: users,
                        sentDate: date941AM
                    )
                },
                // 9. PenPals – group text, Yesterday.
                { () throws(Exception) in
                    try await stagePenPalsConversation(
                        users: users,
                        sentDate: dateYesterday
                    )
                },
            ]

            try await stagers.forEachConcurrently { @Sendable stager throws(Exception) in try await stager() }

            // Reload app with newly staged conversations. The splash
            // page presents on a later run loop pass, so the overlay
            // lifts only once it is on screen.
            Application.reset(
                preserveCurrentUserID: true,
                onCompletion: .navigateToSplash
            )

            Task.delayed(by: .seconds(1)) { @MainActor in
                core.ui.removeOverlay()
                Logger.log(
                    "Staged 9 conversations.",
                    with: .toastInPrerelease(
                        style: .success,
                        isPersistent: true
                    ),
                    sender: self
                )
            }
        } catch {
            core.ui.removeOverlay()
            throw error
        }
    }

    // MARK: - Auxiliary

    private func addTextMessage(
        _ stagedText: StagedText,
        from senderUser: User,
        allParticipants: [User],
        in conversation: Conversation,
        sentDate: Date
    ) async throws(Exception) -> (conversation: Conversation, message: Message) {
        try await addTextMessage(
            text: localizedText(
                stagedText,
                for: senderUser
            ),
            from: senderUser,
            allParticipants: allParticipants,
            in: conversation,
            sentDate: sentDate,
            forcedOutputs: ["en": stagedText.englishText]
        )
    }

    private func addTextMessage(
        text: String,
        from senderUser: User,
        allParticipants: [User],
        in conversation: Conversation,
        sentDate: Date,
        forcedOutputs: [String: String] = [:]
    ) async throws(Exception) -> (conversation: Conversation, message: Message) {
        let translations = try await translateText(
            text,
            from: senderUser,
            toUsers: allParticipants.filter { $0.id != senderUser.id },
            forcedOutputs: forcedOutputs
        )

        let message = try await networking.messageService.buildMessage(
            fromAccountID: senderUser.id,
            richContent: nil,
            sentDate: sentDate,
            translations: translations
        )

        let updatedConversation = try await append(
            message,
            to: conversation
        )

        return (updatedConversation, message)
    }

    private func append(
        _ message: Message,
        to conversation: Conversation
    ) async throws(Exception) -> Conversation {
        // The message fan-out commits the message node, its index
        // entry, the hash tokens, and any pending archive entries
        // atomically.
        var messages = conversation.messages ?? []
        messages.append(message)

        return try await conversation.update(
            \.messages,
            to: messages
        )
    }

    private func buildAudioMessage(
        text: String,
        audioResourceName: String,
        from senderUser: User,
        to recipientUser: User,
        sentDate: Date
    ) async throws(Exception) -> Message {
        guard let audioURL = mainBundle.url(
            forResource: audioResourceName,
            withExtension: "m4a"
        ),
            let audioData = try? Data(contentsOf: audioURL) else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        let translation = try await networking.hostedTranslation.translate(
            .init(text),
            with: .init(
                from: senderUser.languageCode,
                to: recipientUser.languageCode
            ),
            archive: .deferred
        )

        await recordPendingArchiveEntry(for: translation)

        let uniqueID = UUID().uuidString
        let inputURL = fileManager.documentsDirectoryURL.appending(
            path: "staged_audio_\(uniqueID)_input.m4a"
        )

        try fileManager.createFile(
            atPath: inputURL,
            data: audioData
        )

        let outputFileName = "\(recipientUser.languageCode)-output"
        let outputURL = fileManager.documentsDirectoryURL.appending(
            path: "staged_audio_\(uniqueID)_output.m4a"
        )

        try fileManager.createFile(
            atPath: outputURL,
            data: audioData
        )

        let inputFile = AudioFile(
            inputURL,
            name: "staged_audio_\(uniqueID)_input",
            fileExtension: .m4a,
            contentDuration: 0
        )

        let outputFile = AudioFile(
            outputURL,
            name: outputFileName,
            fileExtension: .m4a,
            contentDuration: 0
        )

        let translatedDirectoryPath = "\(NetworkPath.audioTranslations.rawValue)/\(translation.reference.hostingKey)"

        let audioComponent = AudioMessageReference(
            translation: translation,
            original: inputFile,
            translated: outputFile,
            translatedDirectoryPath: translatedDirectoryPath
        )

        return try await networking.messageService.buildMessage(
            fromAccountID: senderUser.id,
            richContent: .audio([audioComponent]),
            sentDate: sentDate,
            translations: [translation]
        )
    }

    private func localizedText(
        _ stagedText: StagedText,
        for senderUser: User
    ) async throws(Exception) -> String {
        // English is canonical; every other language is machine-translated
        // from it, with the English-facing output forced back to the
        // canonical text by the caller.
        let languageCode = senderUser.languageCode
        guard languageCode != "en" else { return stagedText.englishText }

        if let cachedText = $localizedTextCache.withValue({ $0[languageCode]?[stagedText] }) {
            return cachedText
        }

        let text = try await networking.hostedTranslation.translate(
            .init(stagedText.englishText),
            with: .init(
                from: "en",
                to: languageCode
            ),
            enhance: .init(
                additionalContext: "You are translating a casual text message between friends."
            )
        ).output

        $localizedTextCache.withValue { $0[languageCode, default: [:]][stagedText] = text }
        return text
    }

    private func prefetchLocalizedTexts(
        for users: StagedUsers
    ) async throws(Exception) {
        $localizedTextCache.withValue { $0 = [:] }

        // Every case may be sent by the main user; the view-original
        // partner additionally sends their incoming reply.
        var requests = StagedText.allCases.map { ($0, users.mainUser) }
        requests.append((.viewOriginalIncoming, viewOriginalPartner(for: users)))

        try await requests.forEachConcurrently { request throws(Exception) in
            _ = try await localizedText(
                request.0,
                for: request.1
            )
        }
    }

    @MainActor
    private func recordPendingArchiveEntry(
        for translation: Translation
    ) {
        // The entry waits until the message commit that carries
        // it drains it into its payload.
        guard let archiveEntry = networking.hostedTranslation.hostedArchiveEntry(
            for: translation
        ) else { return }

        PendingTranslationArchive.record(
            archiveEntry,
            for: translation.reference.hostingKey
        )
    }

    private func resolveOrCreateUser(
        _ identity: StagedUserIdentity
    ) async throws(Exception) -> User {
        try await stagedUserService.resolveUser(for: identity)
    }

    private func resolveStagedUsers() async throws(Exception) -> StagedUsers {
        try await userSession.resolveCurrentUser()
        guard let currentUser = userSession.currentUser else {
            throw Exception(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        // A twin gives languages without a predefined speaker a
        // same-language perspective on the Beach Day conversation.
        // The main user may themselves be a staged persona; that
        // persona then resolves to the main user, and conversations
        // with themselves are staged as-is.
        let twinIdentity: StagedUserIdentity? = if StagedUserIdentity.all.contains(where: {
            $0.languageCode == currentUser.languageCode
        }) {
            nil
        } else {
            .twin(for: currentUser.languageCode)
        }

        // Remember the main user and twin so Developer Mode can
        // switch perspective between them and the staged users.
        stagedMainUserID = currentUser.id
        stagedTwinLanguageCode = twinIdentity?.languageCode

        let languageTwin: User? = if let twinIdentity {
            try await resolveOrCreateUser(twinIdentity)
        } else {
            nil
        }

        return try await .init(
            erikaMustermann: resolveOrCreateUser(.erikaMustermann),
            jeanDupont: resolveOrCreateUser(.jeanDupont),
            johnAppleseed: resolveOrCreateUser(.johnAppleseed),
            juanPerez: resolveOrCreateUser(.juanPerez),
            mainUser: currentUser,
            languageTwin: languageTwin,
            marioRossi: resolveOrCreateUser(.marioRossi),
            peterIvanov: resolveOrCreateUser(.peterIvanov),
            zhangShan: resolveOrCreateUser(.zhangShan)
        )
    }

    private func stageAppStoreConversation(
        users: StagedUsers,
        sentDate: Date
    ) async throws(Exception) {
        let participants = [
            users.mainUser,
            users.juanPerez,
        ]

        // Create conversation with Juan's first message.
        var conversation = try await stageTextConversation(
            text: "\u{00BF}C\u{00F3}mo puedo hacer que mis amigos empiecen a usar esta aplicaci\u{00F3}n?",
            from: users.juanPerez,
            to: [users.mainUser],
            sentDate: sentDate,
            forcedOutputs: [
                "en": "How can I get my friends to start using this app?",
            ]
        )

        guard let juanMessage1 = conversation.messages?.first else {
            throw Exception(
                "Failed to resolve first message.",
                metadata: .init(sender: self)
            )
        }

        // Add remaining messages.
        conversation = try await addTextMessage(
            .appStoreDownload,
            from: users.mainUser,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(10)
        ).conversation

        let juanReply2 = try await addTextMessage(
            text: "\u{00BF}Entonces no tienen que registrarse con un correo electr\u{00F3}nico y una contrase\u{00F1}a?",
            from: users.juanPerez,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(20),
            forcedOutputs: [
                "en": "So they don\u{2019}t have to sign up with an e-mail and password?",
            ]
        )

        conversation = juanReply2.conversation
        conversation = try await addTextMessage(
            .appStoreVerify,
            from: users.mainUser,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(30)
        ).conversation

        let juanReply3 = try await addTextMessage(
            text: "Guau, esto es incre\u{00ED}ble.",
            from: users.juanPerez,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(40),
            forcedOutputs: [
                "en": "Wow, this is so amazing.",
            ]
        )

        conversation = juanReply3.conversation
        conversation = try await append(
            buildAudioMessage(
                text: localizedText(
                    .appStoreThanks,
                    for: users.mainUser
                ),
                audioResourceName: "audio2",
                from: users.mainUser,
                to: users.juanPerez,
                sentDate: sentDate.addingTimeInterval(50)
            ),
            to: conversation
        )

        // Mark Juan's messages as read.
        try await conversation.updateReadDate(
            for: [
                juanMessage1,
                juanReply2.message,
                juanReply3.message,
            ],
            userID: users.mainUser.id
        )
    }

    private func stageAudioConversation(
        from senderUser: User,
        to recipientUser: User,
        sentDate: Date
    ) async throws(Exception) {
        let message = try await buildAudioMessage(
            text: "Hola, \u{00BF}c\u{00F3}mo est\u{00E1}s?",
            audioResourceName: "audio",
            from: senderUser,
            to: recipientUser,
            sentDate: sentDate
        )

        _ = try await networking.conversationService.createConversation(
            firstMessage: message,
            isPenPalsConversation: false,
            participants: [
                Participant(userID: recipientUser.id),
                Participant(userID: senderUser.id),
            ]
        )
    }

    // swiftlint:disable:next function_body_length
    private func stageBeachDayConversation(
        users: StagedUsers,
        sentDate: Date
    ) async throws(Exception) {
        // Load image from bundle.
        guard let imageURL = mainBundle.url(
            forResource: "image2",
            withExtension: "jpeg"
        ), let imageData = UIImage(
            contentsOfFile: imageURL.path()
        )?.dataCompressed(toKB: 1000) else {
            throw Exception(
                "Failed to resolve required values.",
                metadata: .init(sender: self)
            )
        }

        // Create image file on disk.
        let relativePath = "staged_beach_image.jpeg"
        let localPathURL = fileManager.documentsDirectoryURL.appending(path: relativePath)
        try fileManager.createFile(
            atPath: localPathURL,
            data: imageData
        )

        guard let mediaFile = MediaFile(relativePath) else {
            throw Exception(
                "Failed to create media file.",
                metadata: .init(sender: self)
            )
        }

        // Create image message from main user.
        let imageMessage = try await networking.messageService.buildMessage(
            fromAccountID: users.mainUser.id,
            richContent: .media(mediaFile),
            sentDate: sentDate,
            translations: nil
        )

        // Create group conversation. The twin, when present,
        // only observes, so it never appears in a screenshot.
        var participants = [
            users.mainUser,
            users.erikaMustermann,
            users.jeanDupont,
            users.juanPerez,
            users.marioRossi,
            users.zhangShan,
        ]

        if let languageTwin = users.languageTwin {
            participants.append(languageTwin)
        }

        var conversation = try await networking.conversationService.createConversation(
            firstMessage: imageMessage,
            isPenPalsConversation: false,
            participants: participants.map { Participant(userID: $0.id) }
        )

        // Add text messages.
        conversation = try await addTextMessage(
            .beachDayCheckOut,
            from: users.mainUser,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(10)
        ).conversation

        let zhangReply = try await addTextMessage(
            text: "我们在路上了！",
            from: users.zhangShan,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(20),
            forcedOutputs: [
                "en": "We\u{2019}re on the way!",
            ]
        )

        conversation = zhangReply.conversation
        let marioReply = try await addTextMessage(
            text: "Qualcuno vuole unirsi alla partita di pallavolo?",
            from: users.marioRossi,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(30),
            forcedOutputs: [
                "en": "Anyone else want to get in on that volleyball game?",
            ]
        )

        conversation = marioReply.conversation
        let juanReply = try await addTextMessage(
            text: "\u{00A1}Parece divertido! \u{1F929}",
            from: users.juanPerez,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(40),
            forcedOutputs: [
                "en": "Looks like fun! \u{1F929}",
            ]
        )

        conversation = juanReply.conversation
        conversation = try await addTextMessage(
            .beachDayTable,
            from: users.mainUser,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(50)
        ).conversation

        // Add heart reactions to Mario's volleyball message.
        conversation = try await conversation.update(
            \.reactionMetadata,
            to: [
                ReactionMetadata(
                    messageID: marioReply.message.id,
                    reactions: [
                        Reaction(.love, userID: users.mainUser.id),
                        Reaction(.love, userID: users.juanPerez.id),
                        Reaction(.love, userID: users.zhangShan.id),
                    ]
                ),
            ]
        )

        // Set conversation name and photo.
        guard let conversationImageData = await SquareIconView.image(
            .init(
                backgroundColor: Color(hex: 0x30AAF2),
                overlay: .text(
                    string: "☀️",
                    font: .system(scale: .custom(90))
                )
            )
        )?.dataCompressed(toKB: 100) else {
            throw Exception(
                "Failed to compress conversation image.",
                metadata: .init(sender: self)
            )
        }

        conversation = try await conversation.update(
            \.metadata,
            to: conversation.metadata.copyWith(
                name: "Beach Day \u{1F60E}\u{1F3D6}\u{FE0F}",
                imageData: conversationImageData
            )
        )

        // Mark messages from other users as read.
        try await conversation.updateReadDate(
            for: [
                juanReply.message,
                marioReply.message,
                zhangReply.message,
            ],
            userID: users.mainUser.id
        )
    }

    // swiftlint:disable:next function_parameter_count
    private func stageMediaConversation(
        mediaData: Data,
        mediaFileExtension: MediaFileExtension,
        mediaFileName: String,
        thumbnailData: Data? = nil,
        from senderUser: User,
        to recipientUser: User,
        sentDate: Date
    ) async throws(Exception) -> Conversation {
        let relativePath = "\(mediaFileName).\(mediaFileExtension.rawValue)"
        let localPathURL = fileManager.documentsDirectoryURL.appending(path: relativePath)
        try fileManager.createFile(
            atPath: localPathURL,
            data: mediaData
        )

        if let thumbnailData,
           let thumbnailURL = localPathURL.thumbnailPath {
            try fileManager.createFile(
                atPath: thumbnailURL,
                data: thumbnailData
            )
        }

        guard let mediaFile = MediaFile(relativePath) else {
            throw Exception(
                "Failed to create media file.",
                metadata: .init(sender: self)
            )
        }

        let message = try await networking.messageService.buildMessage(
            fromAccountID: senderUser.id,
            richContent: .media(mediaFile),
            sentDate: sentDate,
            translations: nil
        )

        return try await networking.conversationService.createConversation(
            firstMessage: message,
            isPenPalsConversation: false,
            participants: [
                Participant(userID: recipientUser.id),
                Participant(userID: senderUser.id),
            ]
        )
    }

    private func stagePenPalsConversation(
        users: StagedUsers,
        sentDate: Date
    ) async throws(Exception) {
        let participants = [
            users.mainUser,
            users.erikaMustermann,
            users.juanPerez,
            users.marioRossi,
            users.peterIvanov,
            users.zhangShan,
        ]

        // Create PenPals conversation with mainUser's greeting.
        let conversation = try await stageTextConversation(
            .penPalsGreeting,
            from: users.mainUser,
            to: participants.filter { $0.id != users.mainUser.id },
            sentDate: sentDate,
            isPenPalsConversation: true
        )

        // Add Zhang Shan's reply.
        let zhangReply = try await addTextMessage(
            text: "那些照片太酷了！我们国家没有这些。",
            from: users.zhangShan,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(10),
            forcedOutputs: [
                "en": "Those pictures are so cool! We don\u{2019}t have that in our country.",
            ]
        )

        // Mark Zhang's message as read.
        try await zhangReply.conversation.updateReadDate(
            for: [zhangReply.message],
            userID: users.mainUser.id
        )
    }

    private func stageTextConversation(
        _ stagedText: StagedText,
        from senderUser: User,
        to recipientUsers: [User],
        sentDate: Date,
        isPenPalsConversation: Bool = false
    ) async throws(Exception) -> Conversation {
        try await stageTextConversation(
            text: localizedText(
                stagedText,
                for: senderUser
            ),
            from: senderUser,
            to: recipientUsers,
            sentDate: sentDate,
            forcedOutputs: ["en": stagedText.englishText],
            isPenPalsConversation: isPenPalsConversation
        )
    }

    private func stageTextConversation(
        text: String,
        from senderUser: User,
        to recipientUsers: [User],
        sentDate: Date,
        forcedOutputs: [String: String] = [:],
        isPenPalsConversation: Bool = false
    ) async throws(Exception) -> Conversation {
        let translations = try await translateText(
            text,
            from: senderUser,
            toUsers: recipientUsers,
            forcedOutputs: forcedOutputs
        )

        let message = try await networking.messageService.buildMessage(
            fromAccountID: senderUser.id,
            richContent: nil,
            sentDate: sentDate,
            translations: translations
        )

        var participantUsers = [senderUser]
        participantUsers.append(contentsOf: recipientUsers)

        return try await networking.conversationService.createConversation(
            firstMessage: message,
            isPenPalsConversation: isPenPalsConversation,
            participants: participantUsers.map { Participant(userID: $0.id) }
        )
    }

    private func stageViewOriginalConversation(
        users: StagedUsers,
        sentDate: Date
    ) async throws(Exception) {
        let partner = viewOriginalPartner(for: users)
        let participants = [
            users.mainUser,
            partner,
        ]

        // Create conversation with mainUser's greeting.
        var conversation = try await stageTextConversation(
            .viewOriginalGreeting,
            from: users.mainUser,
            to: [partner],
            sentDate: sentDate
        )

        // Add partner's reply in their language.
        let incomingReply = try await addTextMessage(
            .viewOriginalIncoming,
            from: partner,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(10)
        )

        // Add mainUser's final reply.
        conversation = incomingReply.conversation
        conversation = try await addTextMessage(
            .viewOriginalMeantime,
            from: users.mainUser,
            allParticipants: participants,
            in: conversation,
            sentDate: sentDate.addingTimeInterval(20)
        ).conversation

        // Mark partner's message as read.
        try await conversation.updateReadDate(
            for: [incomingReply.message],
            userID: users.mainUser.id
        )
    }

    /// Pairs the main user with a staged user who speaks a different language.
    private func viewOriginalPartner(
        for users: StagedUsers
    ) -> User {
        users.mainUser.languageCode == "en" ? users.juanPerez : users.johnAppleseed
    }

    private func translateText(
        _ text: String,
        from senderUser: User,
        toUsers recipientUsers: [User],
        forcedOutputs: [String: String] = [:]
    ) async throws(Exception) -> [Translation] {
        try await recipientUsers.map(\.languageCode).unique.parallelMap { languageCode in
            let languagePair = LanguagePair(
                from: senderUser.languageCode,
                to: languageCode
            )

            let translation: Translation = if let forcedOutput = forcedOutputs[languageCode] {
                .init(
                    input: .init(text),
                    output: forcedOutput,
                    languagePair: languagePair
                )
            } else {
                try await networking.hostedTranslation.translate(
                    .init(text),
                    with: languagePair,
                    archive: .deferred
                )
            }

            await recordPendingArchiveEntry(for: translation)
            return translation
        }
    }
}

// swiftlint:enable file_length type_body_length
