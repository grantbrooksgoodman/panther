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

/* 3rd-party */
import MessageKit
import Redux

public struct ChatPageView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    public typealias UIViewControllerType = MessagesViewController

    // MARK: - Dependencies

    @Dependency(\.chatPageViewService) private var viewService: ChatPageViewService

    // MARK: - Properties

    private let conversation: Conversation

    // MARK: - Init

    public init(_ conversation: Conversation) {
        self.conversation = conversation
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> MessagesViewController {
        viewService.createViewController(conversation)
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: MessagesViewController, context: Context) {}
}
