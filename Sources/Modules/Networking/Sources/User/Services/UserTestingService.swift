//
//  UserTestingService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem
import Networking

// swiftlint:disable:next type_body_length
public struct UserTestingService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager
    @Dependency(\.navigation) private var navigation: Navigation
    @Dependency(\.networking) private var networking: NetworkServices

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

    private var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 2 == 0 }
    private var randomPhrase: String {
        var randomPhrase = randomPhrases.randomElement()!

        if randomBool {
            for _ in 0 ... Int.random(in: 1 ... 3) {
                let wordToReplace = randomPhrase.components(separatedBy: " ").randomElement()!
                let replacement = randomWords
                    .filter { $0.count == wordToReplace.count }
                    .randomElement()!
                    .lowercased()

                randomPhrase = randomPhrase.replacingOccurrences(
                    of: wordToReplace,
                    with: replacement
                )
            }
        }

        if randomPhrase.last?.isLetter == true {
            randomPhrase += "?"
        }

        return randomPhrase.firstUppercase
    }

    private var randomUserID: String? {
        get async {
            guard let userData = await userData,
                  let userID = userData.keys.randomElement() else { return nil }
            return userID
        }
    }

    private var randomWords: [String] {
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

    private var userData: [String: Any]? {
        get async {
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
    }

    // MARK: - Create Random Messages

    @MainActor
    public func createRandomMessages(count: Int = 1) async -> Exception? {
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
        @Persistent(.currentUserID) var currentUserID: String?
        let originalCurrentUserID = currentUserID
        defer { currentUserID = originalCurrentUserID }

        currentUserID = (randomBool && randomBool && randomBool) ? (await randomUserID) : currentUserID

        let resolveCurrentUserResult = await clientSession.user.resolveCurrentUser()

        switch resolveCurrentUserResult {
        case let .success(currentUser):
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

                guard let conversation = currentUser.conversations?.randomElement(),
                      let users = conversation.users else { return nil }

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
                    in: nil
                )

            case let .failure(exception):
                return exception
            }

        case let .failure(exception):
            return exception
        }
    }

    private func sendMessage(to users: [User], in conversation: Conversation?) async -> Exception? {
        guard let currentUser = clientSession.user.currentUser else {
            return .init(
                "Current user has not been set.",
                metadata: .init(sender: self)
            )
        }

        if let conversation,
           conversation.metadata.imageData == nil,
           conversation.participants.count > 2,
           let imageData = AppIconImage.local?.dataCompressed(toKB: 100),
           randomBool {
            _ = await conversation.updateValue(
                conversation.metadata.replacing(imageData: imageData),
                forKey: .metadata
            )
        }

        if let conversation,
           conversation.metadata.name.isBangQualifiedEmpty,
           conversation.participants.count > 2,
           randomBool {
            _ = await conversation.updateValue(
                conversation.metadata.replacing(
                    name: randomWords
                        .prefix(Int.random(in: 3 ... 5))
                        .joined(separator: " ")
                ),
                forKey: .metadata
            )
        }

        if randomBool, randomBool {
            guard let data = AppIconImage.local?.dataCompressed(toKB: 100) else {
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
                data: data
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

    // MARK: - Auxiliary

    private func getRandomUsers(
        _ count: Int,
        userData: [String: Any]
    ) async -> Callback<[User], Exception> {
        guard count <= userData.count,
              count >= 1 else {
            return .failure(.init(
                "Requested user count is invalid.",
                metadata: .init(sender: self)
            ))
        }

        var userIDs = [String]()
        while userIDs.count < count {
            guard let randomUserID = userData.keys.randomElement() else { break }
            userIDs.append(randomUserID)
        }

        return await networking.userService.getUsers(ids: userIDs)
    }
}
