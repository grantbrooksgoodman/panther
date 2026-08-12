//
//  DeliveryProgressIndicatorService.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 02/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AppSubsystem

/// The service that manages the message delivery progress bar.
///
/// ``DeliveryProgressIndicatorService`` drives the thin progress bar shown while a message is
/// being sent. It reveals the bar after a short delay, advances it toward – but not past – a
/// threshold on a timer, and completes and hides it once delivery finishes.
@MainActor
final class DeliveryProgressIndicatorService: DeliveryProgressIndicator {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.DeliveryProgressIndicator
    private typealias Strings = AppConstants.Strings.ChatPageViewService.DeliveryProgressIndicator

    // MARK: - Dependencies

    @Dependency(\.clientSession) private var clientSession: ClientSession
    @Dependency(\.messageDeliveryService.isSendingMessage) private var isSendingMessage: Bool

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var appearanceTimer: Timer?
    private var deliveryProgressTimer: Timer?

    // MARK: - Computed Properties

    /// Covers outbox retries, which send without engaging MessageDeliveryService.
    private var isSendingOutboxEntry: Bool {
        guard let conversationIDKey = clientSession.entity.conversation.currentConversation?.id.key else { return false }
        return clientSession.outbox.entries(
            forConversationIDKey: conversationIDKey
        ).contains { $0.state == .sending }
    }

    private var progressView: UIProgressView? {
        viewController.view.firstSubview(for: Strings.viewSemanticTag) as? UIProgressView
    }

    // MARK: - Object Lifecycle

    /// Creates the service, binding it to the given chat page view controller.
    ///
    /// - Parameter viewController: The chat page's messages view controller.
    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    @MainActor
    deinit {
        appearanceTimer?.invalidate()
        appearanceTimer = nil

        deliveryProgressTimer?.invalidate()
        deliveryProgressTimer = nil
    }

    // MARK: - Internal

    /// Advances the progress bar by the given amount, animating the change.
    ///
    /// - Parameter by: The amount to add to the current progress.
    func incrementDeliveryProgress(by: Float) {
        guard let progressView else { return }
        UIView.animate(withDuration: Floats.animationDuration) {
            progressView.setProgress(progressView.progress + by, animated: true)
        }
    }

    /// Begins revealing and advancing the progress bar after a short delay.
    func startAnimatingDeliveryProgress() {
        instantiateDeliveryProgressTimer(Floats.hiddenTimerTimeInterval)
        instantiateAppearanceTimer()
    }

    /// Completes the progress bar, then fades it out and resets it.
    func stopAnimatingDeliveryProgress() {
        deliveryProgressTimer?.invalidate()
        deliveryProgressTimer = nil

        progressView?.setProgress(1, animated: true)
        UIView.animate(
            withDuration: Floats.animationDuration,
            delay: Floats.animationDelay
        ) {
            self.progressView?.alpha = 0
        } completion: { _ in
            self.progressView?.progress = 0
        }
    }

    /// Sets the vertical position of the progress bar.
    ///
    /// - Parameter yOrigin: The vertical origin to apply to the progress bar.
    func updateYOrigin(_ yOrigin: CGFloat) {
        progressView?.frame.origin.y = yOrigin
    }

    // MARK: - Auxiliary

    private func instantiateAppearanceTimer() {
        appearanceTimer?.invalidate()
        appearanceTimer = nil
        appearanceTimer = .scheduledTimer(
            timeInterval: Floats.appearanceTimerTimeInterval,
            target: self,
            selector: #selector(_startAnimatingDeliveryProgress),
            userInfo: nil,
            repeats: false
        )
    }

    private func instantiateDeliveryProgressTimer(_ timeInterval: CGFloat) {
        deliveryProgressTimer?.invalidate()
        deliveryProgressTimer = nil
        deliveryProgressTimer = .scheduledTimer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(_incrementDeliveryProgress),
            userInfo: nil,
            repeats: true
        )
    }

    @objc
    private func _incrementDeliveryProgress() {
        guard let progressView,
              let deliveryProgressTimer,
              deliveryProgressTimer.isValid else { return }

        let incrementValue = Floats.timerProgressIncrement
        let threshold = Floats.timerProgressIncrementThreshold

        guard progressView.progress + .init(incrementValue) < .init(threshold) else { return }
        incrementDeliveryProgress(by: .init(incrementValue))
    }

    @objc
    private func _startAnimatingDeliveryProgress() {
        guard isSendingMessage || isSendingOutboxEntry else { return }
        UIView.animate(withDuration: Floats.animationDuration) {
            self.progressView?.alpha = 1
        } completion: { _ in
            self.instantiateDeliveryProgressTimer(Floats.visibleTimerTimeInterval)
        }
    }
}
