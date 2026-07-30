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

struct CNContactView: View {
    // MARK: - Types

    private enum TaskID: String {
        case hideExtraBackButton
    }

    // MARK: - Properties

    private let cnContact: CNContact
    private let isUnknown: Bool
    private let navigationBarAppearance: NavigationBarAppearance

    // MARK: - Init

    init(
        _ cnContact: CNContact,
        isUnknown: Bool = false,
        navigationBarAppearance: NavigationBarAppearance = Application.isInPrevaricationMode ? .appDefault : .default()
    ) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
        self.navigationBarAppearance = navigationBarAppearance
    }

    // MARK: - View

    var body: some View {
        ThemedView {
            _CNContactView(cnContact, isUnknown: isUnknown)
                .if(!UIApplication.isFullyV26Compatible) {
                    $0.navigationBarBackButtonHidden()
                }
                .navigationTitle("\u{2800}")
                .background(Color.groupedContentBackground)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .onNavigationTransition(.willAppear) { _ in
            NavigationBar.setAppearance(navigationBarAppearance)
        }
        .if(UIApplication.isFullyV26Compatible) {
            $0.onNavigationTransition(.didAppear) { _ in
                hideExtraBackButton()
            }
        }
    }

    // MARK: - Auxiliary

    /// - NOTE: Fixes a bug in which performing-and-cancelling interactive
    /// dismissal on the presented view controller would cause an extraneous
    /// back button to appear as a leading navigation bar item (iOS 26+).
    private func hideExtraBackButton() {
        Task.debounced(
            "\(String.fromCurrentEditorContext(sender: self))/\(TaskID.hideExtraBackButton.rawValue)",
            delay: .milliseconds(10)
        ) { @MainActor in
            @Dependency(\.uiApplication) var uiApplication: UIApplication
            var backButtons: [UIView]? {
                func platterGlassViews(for containerView: UIView?) -> [UIView]? {
                    containerView?
                        .traversedSubviews
                        .filter { $0.descriptor == "PlatterGlassView" }
                }

                if let viewController = uiApplication
                    .presentedViewControllers
                    .filter({
                        $0.activePresentationController is UISheetPresentationController
                    })
                    .first(where: { $0 is CNContactViewController })?
                    .ancestors(type: UIViewController.self)
                    .first?
                    .ancestors(type: UIViewController.self)
                    .first {
                    let platterContainerViews = viewController
                        .view
                        .traversedSubviews
                        .filter { $0.descriptor == "NavigationBarPlatterContainer" }
                        .unique

                    return platterGlassViews(
                        for: platterContainerViews
                            .filter(\.isInSheetPresentation)
                            .last
                    )
                } else {
                    let platterContainerViews = uiApplication
                        .presentedViews
                        .filter { $0.descriptor == "NavigationBarPlatterContainer" }
                        .unique

                    return platterGlassViews(
                        for: uiApplication.isPresentingSheet ? platterContainerViews
                            .filter(\.isInSheetPresentation)
                            .last : platterContainerViews.first
                    )
                }
            }

            guard (backButtons?.count ?? 0) == 2 else { return }
            backButtons?.last?.removeFromSuperview()

            Logger.log(
                "Removed extraneous back button from CNContactViewController navigation bar.",
                domain: .bugPrevention,
                sender: self
            )
        }
    }
}

private struct _CNContactView: UIViewControllerRepresentable {
    // MARK: - Type Aliases

    typealias UIViewControllerType = CNContactViewController

    // MARK: - Dependencies

    @Dependency(\.cnContactStore) private var cnContactStore: CNContactStore

    // MARK: - Properties

    private let cnContact: CNContact
    private let isUnknown: Bool

    // MARK: - Init

    init(
        _ cnContact: CNContact,
        isUnknown: Bool
    ) {
        self.cnContact = cnContact
        self.isUnknown = isUnknown
    }

    // MARK: - Make UIViewController

    func makeUIViewController(context: Context) -> CNContactViewController {
        let viewController: CNContactViewController = isUnknown ? .init(forUnknownContact: cnContact) : .init(for: cnContact)
        viewController.allowsEditing = false

        if isUnknown {
            viewController.contactStore = cnContactStore
            return viewController
        }

        return viewController
    }

    // MARK: - Update UIViewController

    func updateUIViewController(
        _ uiViewController: CNContactViewController,
        context: Context
    ) {}
}

private extension UIView {
    var isInSheetPresentation: Bool {
        sheetPresentationController != nil
    }

    private var owningViewController: UIViewController? {
        sequence(first: next, next: { $0?.next })
            .compactMap { $0 as? UIViewController }
            .first
    }

    private var sheetPresentationController: UISheetPresentationController? {
        guard let owningViewController else { return nil }
        return ([owningViewController] + owningViewController.ancestors(type: UIViewController.self))
            .compactMap { $0.activePresentationController as? UISheetPresentationController }
            .first
    }
}
