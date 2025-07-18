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

public struct ChatPageView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    public typealias UIViewControllerType = MessagesViewController

    // MARK: - Types

    public enum Configuration: Equatable {
        /* MARK: Cases */

        case `default`(focusedMessageID: String?)
        case newChat
        case preview(focusedMessageID: String?)

        /* MARK: Properties */

        public static let `default`: Configuration = .default(focusedMessageID: nil)
        public static let preview: Configuration = .preview(focusedMessageID: nil)

        public var focusedMessageID: String? {
            switch self {
            case let .default(focusedMessageID): return focusedMessageID
            case let .preview(focusedMessageID): return focusedMessageID
            default: return nil
            }
        }

        /* MARK: Equatable Conformance */

        public static func == (left: Configuration, right: Configuration) -> Bool {
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

    public init(_ conversation: Conversation, configuration: Configuration) {
        self.conversation = conversation
        self.configuration = configuration
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> MessagesViewController {
        viewService.instantiateViewController(conversation, configuration: configuration)
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {}
}
