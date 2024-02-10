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

/* 3rd-party */
import Redux

public final class DeliveryProgressIndicatorService: DeliveryProgressIndicator {
    // MARK: - Constants Accessors

    private typealias Floats = AppConstants.CGFloats.DeliveryProgressIndicatorService
    private typealias Strings = AppConstants.Strings.DeliveryProgressIndicatorService

    // MARK: - Dependencies

    @Dependency(\.mainQueue) private var mainQueue: DispatchQueue

    // MARK: - Properties

    private let viewController: ChatPageViewController

    private var deliveryProgressTimer: Timer?

    // MARK: - Computed Properties

    private var progressView: UIProgressView? {
        viewController.view.firstSubview(for: Strings.viewSemanticTag) as? UIProgressView
    }

    // MARK: - Init

    public init(_ viewController: ChatPageViewController) {
        self.viewController = viewController
    }

    // MARK: - Public

    public func incrementDeliveryProgress(by: Float) {
        mainQueue.async {
            guard let progressView = self.progressView else { return }
            UIView.animate(withDuration: Floats.animationDuration) {
                progressView.setProgress(progressView.progress + by, animated: true)
            }
        }
    }

    public func startAnimatingDeliveryProgress() {
        mainQueue.async {
            guard let progressView = self.progressView else { return }
            UIView.animate(withDuration: Floats.animationDuration) {
                progressView.alpha = 1
            } completion: { _ in
                self.deliveryProgressTimer = .scheduledTimer(
                    timeInterval: Floats.timerTimeInterval,
                    target: self,
                    selector: #selector(self._incrementDeliveryProgress),
                    userInfo: nil,
                    repeats: true
                )
            }
        }
    }

    public func stopAnimatingDeliveryProgress() {
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
}
