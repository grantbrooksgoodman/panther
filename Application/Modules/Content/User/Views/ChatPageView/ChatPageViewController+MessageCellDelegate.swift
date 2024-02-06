//
//  ChatPageViewController+MessageCellDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 30/01/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

extension ChatPageViewController: MessageCellDelegate {
    // MARK: - Constants Accessors

    private typealias Strings = AppConstants.Strings.ChatPageView

    // MARK: - Did Select Date

    public func didSelectDate(_ date: Date) {
        guard let url = URL(string: "\(Strings.cellDelegateDateSelectionURLString)\(date.timeIntervalSinceReferenceDate)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select Phone Number

    public func didSelectPhoneNumber(_ phoneNumber: String) {
        guard let url = URL(string: "\(Strings.cellDelegatePhoneNumberSelectionURLString)\(phoneNumber.digits)") else { return }
        didSelectURL(url)
    }

    // MARK: - Did Select URL

    public func didSelectURL(_ url: URL) {
        @Dependency(\.uiApplication) var uiApplication: UIApplication
        Task { @MainActor in
            await uiApplication.open(url)
        }
    }

    // MARK: - Did Tap Play Button

    public func didTapPlayButton(in cell: AudioMessageCell) {
        @Dependency(\.chatPageViewService.audioMessagePlayback) var audioMessagePlaybackService: AudioMessagePlaybackService?
        if let exception = audioMessagePlaybackService?.didTapPlayButton(in: cell) {
            Logger.log(exception, with: .toast())
        }
    }
}
