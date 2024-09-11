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

    public enum Configuration {
        case `default`
        case newChat
        case preview
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
