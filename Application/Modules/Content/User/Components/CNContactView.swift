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

public struct CNContactView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    public typealias UIViewControllerType = CNContactViewController

    // MARK: - Properties

    private let cnContact: CNContact

    // MARK: - Init

    public init(_ cnContact: CNContact) {
        self.cnContact = cnContact
    }

    // MARK: - Make UIViewController

    public func makeUIViewController(context: Context) -> CNContactViewController {
        .init(for: cnContact)
    }

    // MARK: - Update UIViewController

    public func updateUIViewController(_ uiViewController: CNContactViewController, context: Context) {}
}
