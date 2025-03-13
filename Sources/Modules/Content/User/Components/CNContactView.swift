//
//  CNContactView.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import ContactsUI
import Foundation
import SwiftUI

/* Proprietary */
import AppSubsystem

public struct CNContactView: View {
    // MARK: - Properties

    private let cnContact: CNContact
    private let isUnknown: Bool

    // MARK: - Init

    public init(_ cnContact: CNContact, isUnknown: Bool = false) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
    }

    // MARK: - View

    public var body: some View {
        _CNContactView(cnContact, isUnknown: isUnknown)
            .navigationBarBackButtonHidden()
            .navigationTitle("\u{2800}")
            .background(Color.listViewBackground)
    }
}

private struct _CNContactView: UIViewControllerRepresentable {
    // MARK: - Dependencies

    @Dependency(\.cnContactStore) private var cnContactStore: CNContactStore

    // MARK: - Type Aliases

    public typealias UIViewControllerType = CNContactViewController

    // MARK: - Properties

    private let cnContact: CNContact
    private let isUnknown: Bool

    // MARK: - Init

    public init(_ cnContact: CNContact, isUnknown: Bool) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> CNContactViewController {
        if isUnknown {
            let viewController: CNContactViewController = .init(forUnknownContact: cnContact)
            viewController.contactStore = cnContactStore
            return viewController
        }

        return .init(for: cnContact)
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {}
}
