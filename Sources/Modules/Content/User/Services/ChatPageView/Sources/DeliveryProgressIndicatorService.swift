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

final class DeliveryProgressIndicatorService: DeliveryProgressIndicator {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.ChatPageViewService.DeliveryProgressIndicator
    private typealias Strings = AppConstants.Strings.ChatPageViewService.DeliveryProgressIndicator

    // MARK: - Dependencies

    @Dependency(\.coreKit.gcd) private var coreGCD: CoreKit.GCD
    @Dependency(\.messageDeliveryService.isSendingMessage) private var isSendingMessage: Bool
    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var appearanceTimer: Timer?
    private var deliveryProgressTimer: Timer?

    // MARK: - Computed Properties

    private var progressView: UIProgressView? {
        viewController.view.firstSubview(for: Strings.viewSemanticTag) as? UIProgressView
    }

    // MARK: - Object Lifecycle

    init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    deinit {
        appearanceTimer?.invalidate()
        appearanceTimer = nil

        deliveryProgressTimer?.invalidate()
        deliveryProgressTimer = nil
    }

    // MARK: - Internal

    func incrementDeliveryProgress(by: Float) {
        mainQueue.async {
            guard let progressView = self.progressView else { return }
            UIView.animate(withDuration: Floats.animationDuration) {
                progressView.setProgress(progressView.progress + by, animated: true)
            }
        }
    }

    func startAnimatingDeliveryProgress() {
        mainQueue.async {
            self.instantiateDeliveryProgressTimer(Floats.hiddenTimerTimeInterval)
            self.instantiateAppearanceTimer()
        }
    }

    func stopAnimatingDeliveryProgress() {
        deliveryProgressTimer?.invalidate()
        deliveryProgressTimer = nil

        mainQueue.async {
            self.progressView?.setProgress(1, animated: true)
            UIView.animate(
                withDuration: Floats.animationDuration,
                delay: Floats.animationDelay
            ) {
                self.progressView?.alpha = 0
            } completion: { _ in
                self.progressView?.progress = 0
            }
        }
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
        guard isSendingMessage else { return }
        UIView.animate(withDuration: Floats.animationDuration) {
            self.progressView?.alpha = 1
        } completion: { _ in
            self.instantiateDeliveryProgressTimer(Floats.visibleTimerTimeInterval)
        }
    }
}
