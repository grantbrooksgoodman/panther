//
//  TextMessageService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import MessageUI

/* 3rd-party */
import CoreArchitecture

public final class TextMessageService: NSObject, MFMessageComposeViewControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit.ui) private var coreUI: CoreKit.UI

    // MARK: - Compose Text Message

    @discardableResult
    public func composeTextMessage(
        _ text: String,
        recipient phoneNumber: PhoneNumber? = nil
    ) -> Exception? {
        guard MFMessageComposeViewController.canSendText() else {
            return .init("Device is unable to send text messages.", metadata: [self, #file, #function, #line])
        }

        Task { @MainActor in
            let composeVC = MFMessageComposeViewController()
            composeVC.messageComposeDelegate = self
            composeVC.body = text

            if let phoneNumber {
                composeVC.recipients = ["+\(phoneNumber.compiledNumberString)"]
            }

            coreUI.present(composeVC)
        }

        return nil
    }

    // MARK: - MFMessageComposeViewControllerDelegate Conformance

    public func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}
