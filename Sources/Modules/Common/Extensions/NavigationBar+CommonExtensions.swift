//
//  NavigationBar+CommonExtensions.swift
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

public extension NavigationBar {
    // MARK: - Types

    enum ItemPlacement: CaseIterable {
        case leading
        case trailing
    }

    // MARK: - Properties

    private static var isObservingTraitCollectionChanges = false
    private static var knownTintedItems = [Int: UIColor]()

    // MARK: - Methods

    static func removeAllItemGlassTint() {
        Task { @MainActor in
            @Dependency(\.uiApplication) var uiApplication: UIApplication

            let extantGlassViews = knownTintedItems.reduce(into: [Int: UIColor]()) { partialResult, keyPair in
                if !uiApplication.presentedViews.filter({ $0.tag == keyPair.key }).isEmpty {
                    partialResult[keyPair.key] = keyPair.value
                }
            }

            extantGlassViews.forEach { glassView in
                uiApplication
                    .presentedViews
                    .filter { $0.tag == glassView.key }
                    .forEach { $0.backgroundColor = nil }
            }

            isObservingTraitCollectionChanges = false
            knownTintedItems = [:]
        }
    }

    static func setItemGlassTint(
        _ color: UIColor,
        for placement: ItemPlacement,
        delay: Duration = .zero
    ) {
        guard UIApplication.isGlassTintingEnabled else { return }

        guard delay > .zero else {
            Task { @MainActor in
                _setItemGlassTint(color, for: placement)
            }

            return
        }

        Task.delayed(by: delay) { @MainActor in
            _setItemGlassTint(color, for: placement)
        }
    }

    @MainActor
    private static func startObservingTraitCollectionChanges() {
        @Dependency(\.notificationCenter) var notificationCenter: NotificationCenter
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        guard !isObservingTraitCollectionChanges else { return }
        isObservingTraitCollectionChanges = true

        notificationCenter.addObserver(
            UIApplication.shared,
            name: .init("traitCollectionChangedNotification")
        ) { _ in
            guard isObservingTraitCollectionChanges else { return }
            Task.delayed(by: .milliseconds(100)) { @MainActor in
                let extantGlassViews = knownTintedItems.reduce(into: [Int: UIColor]()) { partialResult, keyPair in
                    if !uiApplication.presentedViews.filter({ $0.tag == keyPair.key }).isEmpty {
                        partialResult[keyPair.key] = keyPair.value
                    }
                }

                knownTintedItems = extantGlassViews
                guard !extantGlassViews.isEmpty else {
                    notificationCenter.removeObserver(
                        UIApplication.shared,
                        name: .init("traitCollectionChangedNotification"),
                        object: nil
                    )
                    return isObservingTraitCollectionChanges = false
                }

                extantGlassViews.forEach { glassView in
                    uiApplication
                        .presentedViews
                        .filter { $0.tag == glassView.key }
                        .forEach { $0.backgroundColor = glassView.value }
                }
            }
        }
    }

    @MainActor
    private static func _setItemGlassTint(_ color: UIColor, for placement: ItemPlacement) {
        @Dependency(\.coreKit.ui) var coreUI: CoreKit.UI
        @Dependency(\.uiApplication) var uiApplication: UIApplication

        var platterContainerViews: [UIView] {
            uiApplication
                .presentedViews
                .filter { $0.descriptor == "NavigationBarPlatterContainer" }
                .unique
        }

        var platterGlassViews: [UIView]? {
            let containerView = uiApplication.isPresentingSheet ? platterContainerViews
                .filter(\.isInSheetPresentation)
                .last : platterContainerViews.first

            return containerView?
                .traversedSubviews
                .filter { $0.descriptor == "PlatterGlassView" }
        }

        var leadingItem: UIView? {
            guard let firstItem = platterGlassViews?.first,
                  let lastSuperview = firstItem.traversedSuperviews.last,
                  let frameInLastSuperview = firstItem.frame(in: lastSuperview),
                  frameInLastSuperview.origin.x <= uiApplication.mainScreen.bounds.midX else { return nil }
            return firstItem
        }

        var trailingItem: UIView? {
            guard let lastItem = platterGlassViews?.last,
                  let lastSuperview = lastItem.traversedSuperviews.last,
                  let frameInLastSuperview = lastItem.frame(in: lastSuperview),
                  frameInLastSuperview.origin.x >= uiApplication.mainScreen.bounds.midX else { return nil }
            return lastItem
        }

        switch placement {
        case .leading:
            guard let leadingItem else { return }
            UIView.animate(withDuration: 0.2) {
                leadingItem.backgroundColor = color
            } completion: { _ in
                leadingItem.tag = coreUI.semTag(for: "LEADING_COLORED_GLASS_\(knownTintedItems.count)")
                knownTintedItems[leadingItem.tag] = color
            }

        case .trailing:
            guard let trailingItem else { return }
            UIView.animate(withDuration: 0.2) {
                trailingItem.backgroundColor = color
            } completion: { _ in
                trailingItem.tag = coreUI.semTag(for: "TRAILING_COLORED_GLASS_\(knownTintedItems.count)")
                knownTintedItems[trailingItem.tag] = color
            }
        }

        startObservingTraitCollectionChanges()
    }
}

private extension UIView {
    var isInSheetPresentation: Bool { sheetPresentationController != nil }

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
