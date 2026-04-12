//
//  ChatPageView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

/* 3rd-party */
import MessageKit

struct ChatPageView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    typealias UIViewControllerType = MessagesViewController

    // MARK: - Types

    enum Configuration: Equatable {
        /* MARK: Cases */

        case `default`(focusedMessageID: String?)
        case newChat
        case preview(focusedMessageID: String?)

        /* MARK: Properties */

        static let `default`: Configuration = .default(focusedMessageID: nil)
        static let preview: Configuration = .preview(focusedMessageID: nil)

        var focusedMessageID: String? {
            switch self {
            case let .default(focusedMessageID): focusedMessageID
            case let .preview(focusedMessageID): focusedMessageID
            default: nil
            }
        }

        /* MARK: Equatable Conformance */

        static func == (left: Configuration, right: Configuration) -> Bool {
            switch (left, right) {
            case(.default, .default),
                 (.newChat, .newChat),
                 (.preview, .preview): true

            default: false
            }
        }
    }

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var viewService: ChatPageViewService

    // MARK: - Properties

    private let configuration: Configuration
    private let conversation: Conversation

    // MARK: - Init

    init(_ conversation: Conversation, configuration: Configuration) {
        self.conversation = conversation
        self.configuration = configuration
    }

    // MARK: - Make UIViewController

    func makeUIViewController(context: Context) -> MessagesViewController {
        viewService.instantiateViewController(conversation, configuration: configuration)
    }

    // MARK: - Update UIViewController

    func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {}
}
