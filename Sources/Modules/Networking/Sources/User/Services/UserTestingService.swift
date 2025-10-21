//
//  UserTestingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

// swiftlint:disable file_length type_body_length

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

public struct UserTestingService {
    // MARK: - Dependencies

    @Dependency(\.alertKitConfig) private var alertKitConfig: AlertKit.Config
    @Dependency(\.build) private var build: Build
    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices
    @Dependency(\.uiApplication) private var uiApplication: UIApplication
    @Dependency(\.commonServices.update) private var updateService: UpdateService

    // MARK: - Properties

    private let randomPhrases = [
        "Are you still coming tonight?",
        "Can you believe what happened today?",
        "Can you help me with this problem?",
        "Can you help me with this task?",
        "Can you send me the report?",
        "Can you share the link again?",
        "Do you think it's going to rain tomorrow?",
        "Do you want to grab lunch later?",
        "Do you want to meet up this weekend?",
        "Have you heard about the new restaurant in town?",
        "Have you seen the new movie yet?",
        "He plays the guitar very well.",
        "He traveled to five countries last year.",
        "Her dog loves to run in the park.",
        "Her favorite color is blue.",
        "Hey, are you free later?",
        "His favorite color is blue.",
        "I think I left my keys at home.",
        "I was thinking about you today.",
        "I'll be there in 10 minutes!",
        "I'll get back to you on that.",
        "Is now a good time to chat?",
        "Just checking in, how's your day going?",
        "Let's catch up soon!",
        "She enjoys reading books in her free time.",
        "Sorry, I missed your message.",
        "Thanks for sending that over!",
        "That movie was really interesting.",
        "That was an incredible experience!",
        "The cake smells delicious.",
        "The quick brown fox jumps over the lazy dog.",
        "The weather is nice today, isn't it?",
        "The weather is perfect for a walk.",
        "They traveled to Japan last summer.",
        "They're planning a surprise party.",
    ]

    // MARK: - Computed Properties

    private var isOnProperEnvironment: Bool { getIsOnProperEnvironment() }

    private var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 2 == 0 }
    private var randomEmoji: String { getRandomEmoji() }
    private var randomImageData: Data? {
        get async { await getRandomImageData() }
    }

    private var randomPhrase: String { getRandomPhrase() }
    private var randomUserID: String? {
        get async { await getRandomUserID() }
    }

    private var randomWords: [String] { getRandomWords() }
    private var userData: [String: Any]? {
        get async { await getUserData() }
    }

    // MARK: - Create Random Messages

    @MainActor
    public func createRandomMessages(count: Int = 1) async -> Exception? {
        guard isOnProperEnvironment else {
            return .environmentIntrusionDetected(
                metadata: .init(sender: self)
            )
        }

        core.ui.addOverlay(
            alpha: 0.5,
            activityIndicator: .largeWhite
        )

        let originalCount = count
        var count = count

        clientSession.user.stopObservingCurrentUserChanges()
        while count > 0 {
            if let exception = await createRandomMessage() {
                core.ui.removeOverlay()
                return exception
            }

            count -= 1
        }

        navigation.navigate(to: .root(.modal(.splash)))
        core.ui.removeOverlay()
        core.gcd.after(.seconds(1)) {
            core.hud.showSuccess(
                text: "Created \(originalCount) new message\(originalCount == 1 ? "" : "s")"
            )
        }

        return nil
    }

    private func createRandomMessage() async -> Exception? {
        guard isOnProperEnvironment else {
            return .environmentIntrusionDetected(
                metadata: .init(sender: self)
            )
        }

        @Persistent(.currentUserID) var currentUserID: String?
        let originalCurrentUserID = currentUserID
        defer { currentUserID = originalCurrentUserID }

        currentUserID = (randomBool && randomBool && randomBool) ? (await randomUserID) : currentUserID

        let resolveCurrentUserResult = await clientSession.user.resolveCurrentUser()

        switch resolveCurrentUserResult {
        case let .success(currentUser):
            if let exception = await clientSession.user.resolveAndSetLanguageCode() {
                return exception
            }

            guard randomBool else {
                if currentUserID != originalCurrentUserID {
                    Application.reset(preserveCurrentUserID: true)
                    if let exception = await networking.database.populateTemporaryCaches() {
                        return exception
                    }
                }

                try? await Task.sleep(for: .seconds(1))
                if let exception = await currentUser.setConversations() {
                    return exception
                }

                if let exception = await currentUser.conversations?.setUsers() {
                    return exception
                }

                guard let conversation = randomBool && randomBool ?
                    currentUser
                    .conversations?
                    .randomElement() :
                    currentUser
                    .conversations?
                    .filter({
                        $0.messages?
                            .sortedByDescendingSentDate
                            .first?
                            .fromAccountID != User.currentUserID
                    })
                    .randomElement(),
                    let users = conversation.users else { return await createRandomMessage() }

                if randomBool {
                    await setImage(for: conversation)
                } else {
                    await setRandomTitle(for: conversation)
                }

                return await sendMessage(
                    to: users.sorted(by: { $0.id < $1.id }),
                    in: conversation
                )
            }

            guard let userData = await userData,
                  userData.count > 1 else {
                return .init(
                    "Failed to resolve user data or not enough users on server.",
                    metadata: .init(sender: self)
                )
            }

            let getRandomUsersResult = await getRandomUsers(
                randomBool ? Int.random(in: 1 ... userData.count) : 1,
                userData: userData
            )

            switch getRandomUsersResult {
            case let .success(randomUsers):
                let filteredUsers = randomUsers.filter { $0.id != currentUser.id }.unique
                guard !filteredUsers.isEmpty else { return nil }
                return await sendMessage(
                    to: filteredUsers.sorted(by: { $0.id < $1.id }),
                    in: filteredUsers.count == 1 ? currentUser
                        .conversations?
                        .first(where: {
                            $0.participants.count == 2 &&
                                $0.participants.map(\.userID).contains(filteredUsers.first!.id)
                        }) : currentUser
                        .conversations?
                        .first(where: {
                            filteredUsers.map(\.id).containsAllStrings(in: $0.participants.map(\.userID))
                        })
                )

            case let .failure(exception):
                return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    private func sendMediaMessage(to users: [User], in conversation: Conversation?) async -> Exception? {
        guard isOnProperEnvironment else {
            return .environmentIntrusionDetected(
                metadata: .init(sender: self)
            )
        }

        guard let imageData = await randomImageData else {
            return .init(
                "Failed to compress image.",
                metadata: .init(sender: self)
            )
        }

        // swiftlint:disable:next line_length
        let relativePath = "\(NetworkPath.media.rawValue)/\(AppConstants.Strings.ChatPageViewService.MediaActionHandler.defaultImageName).\(MediaFileExtension.image(.jpeg).rawValue)"
        let localPathURL = fileManager.documentsDirectoryURL.appending(path: relativePath)

        if let exception = fileManager.createFile(
            atPath: localPathURL,
            data: imageData
        ) {
            return exception
        }

        let sendMediaMessageResult = await clientSession.message.sendMediaMessage(
            .init(
                relativePath,
                name: AppConstants.Strings.ChatPageViewService.MediaActionHandler.defaultImageName,
                fileExtension: .image(.jpeg)
            ),
            toUsers: users,
            inConversation: (conversation, false)
        )

        switch sendMediaMessageResult {
        case .success: return nil
        case let .failure(exception): return exception
        }
    }

    private func sendMessage(to users: [User], in conversation: Conversation?) async -> Exception? {
        guard isOnProperEnvironment else {
            return .environmentIntrusionDetected(
                metadata: .init(sender: self)
            )
        }

        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        if randomBool, randomBool {
            return await sendMediaMessage(to: users, in: conversation)
        }

        let translateResult = await networking.hostedTranslation.translate(
            .init(randomPhrase),
            with: .init(from: "en", to: currentUser.languageCode)
        )

        switch translateResult {
        case let .success(translation):
            let sendTextMessageResult = await clientSession.message.sendTextMessage(
                translation.output,
                toUsers: users,
                inConversation: (conversation, false)
            )

            switch sendTextMessageResult {
            case .success: return nil
            case let .failure(exception): return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    // MARK: - Computed Property Getters

    private func getIsOnProperEnvironment() -> Bool {
        guard Networking.config.environment == .production else { return true }

        alertKitConfig.registerPresentationDelegate(DummyPresentationDelegate.shared)
        core.ui.addOverlay(activityIndicator: nil)
        updateService.isForcedUpdateRequiredSubject.send(true)

        Task.delayed(by: .milliseconds(300)) { @MainActor in
            self.core.ui.removeOverlay()
            self.core.ui.addOverlay(
                activityIndicator: nil,
                isModal: false
            )

            self.alertKitConfig.registerPresentationDelegate(self.core)
            let resetAction: AKAction = .init(
                "Reset Application",
                style: .destructivePreferred
            ) {
                Application.reset(onCompletion: .exitGracefully)
            }

            let environmentIntrusionAlert = AKAlert(
                title: "!! ENVIRONMENT INTRUSION DETECTED !!", // swiftlint:disable:next line_length
                message: "An unintentional intrusion into the Production environment has been detected. Read/write access has been disabled.\n\nThe application must now be reset. Please validate Production database integrity upon relaunch.",
                actions: [resetAction]
            )

            environmentIntrusionAlert.setTitleAttributes(.init([
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.red,
            ]))

            environmentIntrusionAlert.setMessageAttributes(
                .init(
                    [.font: UIFont.systemFont(ofSize: 15)],
                    secondaryAttributes: [.init(
                        [.font: UIFont.systemFont(ofSize: 15, weight: .semibold)],
                        stringRanges: ["Please validate Production database integrity upon relaunch."]
                    )]
                )
            )

            await environmentIntrusionAlert.present(translating: [])
        }

        return false
    }

    private func getRandomEmoji() -> String {
        let emojiRanges: [ClosedRange<Int>] = [
            0x1F600 ... 0x1F64F, // Emoticons
            0x1F300 ... 0x1F5FF, // Misc Symbols & Pictographs
            0x1F680 ... 0x1F6FF, // Transport & Map
            0x1F900 ... 0x1F9FF, // Supplemental Symbols & Pictographs
        ]

        guard let range = emojiRanges.randomElement() else { return "#️⃣" }
        let scalarValue = Int.random(in: range)
        guard let unicodeScalar = UnicodeScalar(scalarValue) else { return "#️⃣" }
        return .init(unicodeScalar)
    }

    private func getRandomImageData() async -> Data? {
        await(randomBool ? UIImage.appIcon : SquareIconView.image(
            .init(
                backgroundColor: .random,
                overlay: .text(
                    string: randomEmoji,
                    font: .system(scale: .custom(90))
                )
            )
        ))?.dataCompressed(toKB: 10)
    }

    private func getRandomPhrase() -> String {
        var randomPhrase = randomPhrases.randomElement() ?? "Hello, world!"

        if randomBool {
            for _ in 0 ... Int.random(in: 1 ... 3) {
                guard let wordToReplace = randomPhrase
                    .components(separatedBy: " ")
                    .randomElement(),
                    let replacementWord = (
                        randomBool ?
                            randomWords
                            .randomElement() :
                            randomWords
                            .filter { $0.count == wordToReplace.count }
                            .randomElement()
                    )?.lowercased() else { continue }

                randomPhrase = randomPhrase.replacingOccurrences(
                    of: wordToReplace,
                    with: replacementWord
                )
            }
        }

        if randomPhrase.last?.isLetter == true {
            randomPhrase += "?"
        }

        return randomPhrase.firstUppercase
    }

    private func getRandomUserID() async -> String? {
        guard let userData = await userData,
              let userID = userData.keys.randomElement() else { return nil }
        return userID
    }

    private func getRandomWords() -> [String] {
        randomPhrases
            .joined(separator: " ")
            .filter {
                !$0
                    .unicodeScalars
                    .allSatisfy(CharacterSet.punctuationCharacters.contains)
            }
            .components(separatedBy: " ")
            .shuffled()
    }

    private func getUserData() async -> [String: Any]? {
        let getValuesResult = await networking.database.getValues(at: NetworkPath.users.rawValue)

        switch getValuesResult {
        case let .success(values):
            guard let dictionary = values as? [String: Any] else { return nil }
            return dictionary

        case let .failure(exception):
            Logger.log(exception)
            return nil
        }
    }

    // MARK: - Auxiliary

    private func getRandomUsers(
        _ count: Int,
        userData: [String: Any]
    ) async -> Callback<[User], Exception> {
        guard isOnProperEnvironment else {
            return .failure(
                .environmentIntrusionDetected(metadata: .init(sender: self))
            )
        }

        guard count <= userData.count,
              count >= 1 else {
            return .failure(.init(
                "Requested user count is invalid.",
                metadata: .init(sender: self)
            ))
        }

        var userIDs = Set<String>()
        while userIDs.count < count {
            guard let randomUserID = userData.keys.randomElement() else { break }
            userIDs.insert(randomUserID)
        }

        return await networking.userService.getUsers(ids: .init(userIDs))
    }

    private func setImage(for conversation: Conversation?) async {
        guard isOnProperEnvironment else {
            return Logger.log(
                .environmentIntrusionDetected(metadata: .init(sender: self))
            )
        }

        guard let conversation,
              conversation.metadata.imageData == nil,
              conversation.participants.count > 2,
              let imageData = await randomImageData else { return }

        do {
            _ = try (await conversation.updateValue(
                conversation.metadata.copyWith(imageData: imageData),
                forKey: .metadata
            )).get()
        } catch {
            Logger.log(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }

    private func setRandomTitle(for conversation: Conversation?) async {
        guard isOnProperEnvironment else {
            return Logger.log(
                .environmentIntrusionDetected(metadata: .init(sender: self))
            )
        }

        guard let conversation,
              conversation.metadata.name.isBangQualifiedEmpty,
              conversation.participants.count > 2 else { return }

        var randomTitle = randomWords
            .prefix(Int.random(in: 3 ... 5))
            .joined(separator: " ")
            .lowercased()

        // swiftlint:disable duplicate_conditions
        if randomBool {
            randomTitle = randomTitle.firstUppercase
        } else if randomBool {
            randomTitle = randomTitle.uppercased()
        } // swiftlint:enable duplicate_conditions

        do {
            _ = try (await conversation.updateValue(
                conversation.metadata.copyWith(name: randomTitle),
                forKey: .metadata
            )).get()
        } catch {
            Logger.log(.init(
                error,
                metadata: .init(sender: self)
            ))
        }
    }
}

private struct DummyPresentationDelegate: AlertKit.PresentationDelegate {
    // MARK: - Properties

    static let shared = DummyPresentationDelegate()

    let presentedAlertControllers: [UIAlertController] = []

    // MARK: - Init

    private init() {}

    // MARK: - Methods

    func present(_ alertController: UIAlertController) {}
}

private extension Exception {
    static func environmentIntrusionDetected(
        metadata: ExceptionMetadata
    ) -> Exception {
        .init(
            "Intrusion into the Production environment detected.",
            metadata: metadata
        )
    }
}

// swiftlint:enable file_length type_body_length
