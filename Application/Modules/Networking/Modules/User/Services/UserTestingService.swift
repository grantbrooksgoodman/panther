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

public struct UserTestingService {
    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.uiApplication.keyViewController) private var keyViewController: UIViewController?
    @Dependency(\.networking) private var networking: NetworkServices

    // MARK: - Properties

    private var randomUserID: String? {
        get async {
            guard let userData = await userData,
                  let userID = userData.keys.randomElement() else { return nil }
            return userID
        }
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
        keyViewController?.view.addOverlay(alpha: 0.5, activityIndicator: (.large, .white))
        let originalCount = count
        var count = count

        while count > 0 {
            if let exception = await createRandomMessage() {
                keyViewController?.view.removeOverlay()
                return exception
            }

            count -= 1
        }

        keyViewController?.view.removeOverlay()
        Toast.show(.init(
            .capsule(style: .success),
            message: "Created \(originalCount) new message(s)",
            perpetuation: .ephemeral(.seconds(5))
        ))
        return nil
    }

    private func createRandomMessage() async -> Exception? {
        func sendMessage(to users: [User], in conversation: Conversation?) async -> Exception? {
            guard let currentUser = clientSession.user.currentUser else {
                return .init(
                    "Current user has not been set.",
                    metadata: [self, #file, #function, #line]
                )
            }

            let translateResult = await networking.translationService.translate(
                .init(randomPhrases.randomElement() ?? "Hello world!"),
                with: .init(from: "en", to: currentUser.languageCode)
            )

            switch translateResult {
            case let .success(translation):
                let sendTextMessageResult = await clientSession.message.sendTextMessage(
                    translation.output,
                    toUsers: users,
                    inConversation: conversation
                )

                switch sendTextMessageResult {
                case .success:
                    return nil

                case let .failure(exception):
                    return exception
                }

            case let .failure(exception):
                return exception
            }
        }

        let randomPhrases = [
            "Tom got a small piece of pie.",
            "Two more days and all his problems would be solved.",
            "Two seats were vacant.",
            "We have a lot of rain in June.",
            "We have never been to Asia, nor have we visited Africa.",
            "We need to rent a room for our party.",
            "When I was little I had a car door slammed shut on my hand and I still remember it quite vividly.",
            "Writing a list of random sentences is harder than I initially thought it would be.",
            "Yeah, I think it's a good environment for learning English.",
            "You can't compare apples and oranges, but what about bananas and plantains?",
        ]

        @Persistent(.currentUserID) var currentUserID: String?
        currentUserID = await randomUserID

        let setCurrentUserResult = await clientSession.user.setCurrentUser()

        switch setCurrentUserResult {
        case let .success(currentUser):
            var randomBool: Bool { Int.random(in: 1 ... 1_000_000) % 2 == 0 }
            guard randomBool, randomBool, randomBool else {
                if let exception = await currentUser.setConversations() {
                    return exception
                }

                if let exception = await currentUser.conversations?.setUsers() {
                    return exception
                }

                guard let conversation = currentUser.conversations?.randomElement(),
                      let users = conversation.users else { return nil }
                return await sendMessage(to: users.sorted(by: { $0.id < $1.id }), in: conversation)
            }

            guard let userData = await userData,
                  userData.count > 1 else {
                return .init(
                    "Failed to resolve user data or not enough users on server.",
                    metadata: [self, #file, #function, #line]
                )
            }

            let getRandomUsersResult = await getRandomUsers(
                Int.random(in: 1 ... userData.count),
                userData: userData
            )

            switch getRandomUsersResult {
            case let .success(randomUsers):
                let filteredUsers = randomUsers.filter { $0.id != currentUser.id }.unique
                guard !filteredUsers.isEmpty else { return nil }
                return await sendMessage(to: filteredUsers.sorted(by: { $0.id < $1.id }), in: nil)

            case let .failure(exception):
                return exception
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
                metadata: [self, #file, #function, #line]
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
