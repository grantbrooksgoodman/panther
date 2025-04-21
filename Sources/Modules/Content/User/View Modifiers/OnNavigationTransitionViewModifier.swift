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
    case pop
    case push
}

private struct OnNavigationTransitionViewModifier: ViewModifier {
    // MARK: - Properties

    private let onViewWillAppear: ((Duration) -> Void)?
    private let onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public init(
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .background(
                TransitionDurationReader(
                    onViewWillAppear: onViewWillAppear,
                    onViewWillDisappear: onViewWillDisappear
                )
                .frame(width: .zero, height: .zero)
            )
    }
}

private struct TransitionDurationReader: UIViewControllerRepresentable {
    // MARK: - Properties

    private let onViewWillAppear: ((Duration) -> Void)?
    private let onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public init(
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - Make UIViewController

    func makeUIViewController(context: Context) -> TransitionTrackingViewController {
        .init(
            onViewWillAppear: onViewWillAppear,
            onViewWillDisappear: onViewWillDisappear
        )
    }

    // MARK: - Update UIViewController

    func updateUIViewController(_ uiViewController: TransitionTrackingViewController, context: Context) {}
}

private final class TransitionTrackingViewController: UIViewController {
    // MARK: - Properties

    private var onViewWillAppear: ((Duration) -> Void)?
    private var onViewWillDisappear: ((Duration) -> Void)?

    // MARK: - Init

    public convenience init(
        onViewWillAppear: ((Duration) -> Void)?,
        onViewWillDisappear: ((Duration) -> Void)?
    ) {
        self.init()
        self.onViewWillAppear = onViewWillAppear
        self.onViewWillDisappear = onViewWillDisappear
    }

    // MARK: - View Lifecycle

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
}

public extension View {
    func onNavigationTransition(
        _ transition: NavigationTransition,
        effect: @escaping ((Duration) -> Void)
    ) -> some View {
        modifier(
            OnNavigationTransitionViewModifier(
                onViewWillAppear: transition == .pop ? nil : effect,
                onViewWillDisappear: transition == .pop ? effect : nil
            )
        )
    }
}
