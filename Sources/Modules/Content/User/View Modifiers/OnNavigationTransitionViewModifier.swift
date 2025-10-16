//
//  OnNavigationTransitionViewModifier.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 16/04/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import SwiftUI

public enum NavigationTransition {
    case didAppear
    case didDisappear
    case willAppear
    case willDisappear
}

private struct OnNavigationTransitionViewModifier: ViewModifier {
    // MARK: - Properties

    private let onViewDidAppear: ((Duration) -> Void)?
    private let onViewDidDisappear: ((Duration) -> Void)?
    private let onViewWillAppear: ((Duration) -> Void)?
    private let onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public init(
        onViewDidAppear: ((Duration) -> Void)?,
        onViewDidDisappear: ((Duration) -> Void)?,
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.onViewDidAppear = onViewDidAppear
        self.onViewDidDisappear = onViewDidDisappear
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .background(
                TransitionDurationReader(
                    onViewDidAppear: onViewDidAppear,
                    onViewDidDisappear: onViewDidDisappear,
                    onViewWillAppear: onViewWillAppear,
                    onViewWillDisappear: onViewWillDisappear
                )
                .frame(width: .zero, height: .zero)
            )
    }
}

private struct TransitionDurationReader: UIViewControllerRepresentable {
    // MARK: - Properties

    private let onViewDidAppear: ((Duration) -> Void)?
    private let onViewDidDisappear: ((Duration) -> Void)?
    private let onViewWillAppear: ((Duration) -> Void)?
    private let onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public init(
        onViewDidAppear: ((Duration) -> Void)?,
        onViewDidDisappear: ((Duration) -> Void)?,
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.onViewDidAppear = onViewDidAppear
        self.onViewDidDisappear = onViewDidDisappear
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - Make UIViewController

    func makeUIViewController(context: Context) -> TransitionTrackingViewController {
        .init(
            onViewDidAppear: onViewDidAppear,
            onViewDidDisappear: onViewDidDisappear,
            onViewWillAppear: onViewWillAppear,
            onViewWillDisappear: onViewWillDisappear
        )
    }

    // MARK: - Update UIViewController

    func updateUIViewController(_ uiViewController: TransitionTrackingViewController, context: Context) {}
}

private final class TransitionTrackingViewController: UIViewController {
    // MARK: - Properties

    private var onViewDidAppear: ((Duration) -> Void)?
    private var onViewDidDisappear: ((Duration) -> Void)?
    private var onViewWillAppear: ((Duration) -> Void)?
    private var onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public convenience init(
        onViewDidAppear: ((Duration) -> Void)?,
        onViewDidDisappear: ((Duration) -> Void)?,
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.init()
        self.onViewDidAppear = onViewDidAppear
        self.onViewDidDisappear = onViewDidDisappear
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - Appearance

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let transitionCoordinator else {
            onViewWillAppear?(.zero)
            return
        }

        transitionCoordinator.animate(alongsideTransition: nil) { _ in
            self.onViewWillAppear?(.seconds(transitionCoordinator.transitionDuration))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let transitionCoordinator else {
            onViewDidAppear?(.zero)
            return
        }

        transitionCoordinator.animate(alongsideTransition: nil) { _ in
            self.onViewDidAppear?(.seconds(transitionCoordinator.transitionDuration))
        }
    }

    // MARK: - Disappearance

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        guard let transitionCoordinator else {
            onViewWillDisappear?(.zero)
            return
        }

        transitionCoordinator.animate(alongsideTransition: nil) { _ in
            self.onViewWillDisappear?(.seconds(transitionCoordinator.transitionDuration))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard let transitionCoordinator else {
            onViewDidDisappear?(.zero)
            return
        }

        transitionCoordinator.animate(alongsideTransition: nil) { _ in
            self.onViewDidDisappear?(.seconds(transitionCoordinator.transitionDuration))
        }
    }
}

public extension View {
    func onNavigationTransition(
        _ transition: NavigationTransition,
        effect: @escaping ((Duration) -> Void)
    ) -> some View {
        modifier(
            OnNavigationTransitionViewModifier(
                onViewDidAppear: transition == .didAppear ? effect : nil,
                onViewDidDisappear: transition == .didDisappear ? effect : nil,
                onViewWillAppear: transition == .willAppear ? effect : nil,
                onViewWillDisappear: transition == .willDisappear ? effect : nil
            )
        )
    }
}
