//
//  ChatPageViewController+AVSpeechSynthesizerDelegate.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 07/02/2024.
//  Copyright © 2013-2024 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import AVFAudio
import Foundation
import UIKit

/* 3rd-party */
import MessageKit
import Redux

extension ChatPageViewController: AVSpeechSynthesizerDelegate {
    // MARK: - Did Cancel Utterance

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        menuService?.dismissMenu()

        guard let speakingCell = menuService?.speakingCell,
              let indexPath = messagesCollectionView.indexPath(for: speakingCell) else { return }

        messagesCollectionView.reloadItems(at: [indexPath])
        menuService?.resetSpeakingCell()
    }

    // MARK: - Did Finish Utterance

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        menuService?.dismissMenu()

        guard let speakingCell = menuService?.speakingCell,
              let indexPath = messagesCollectionView.indexPath(for: speakingCell) else { return }

        messagesCollectionView.reloadItems(at: [indexPath])
        menuService?.resetSpeakingCell()
    }

    // MARK: - Will Speak Range of Speech String

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?

        guard let speakingCell = menuService?.speakingCell as? TextMessageCell,
              let speakingMessage = menuService?.speakingMessage,
              messagesCollectionView.visibleCells.contains(speakingCell),
              let labelFont = speakingCell.messageLabel.font,
              let labelText = speakingCell.messageLabel.text else { return }

        let shouldUseWhite = speakingMessage.isFromCurrentUser || UITraitCollection.current.userInterfaceStyle == .dark
        let attributedString = NSMutableAttributedString(string: labelText)

        guard characterRange.lowerBound >= 0,
              characterRange.lowerBound < attributedString.length,
              characterRange.upperBound > 0,
              characterRange.upperBound < attributedString.length,
              characterRange.lowerBound < characterRange.upperBound else { return }

        typealias Colors = AppConstants.Colors.ChatPageView.AVSpeechSynthesizerDelegate
        typealias Floats = AppConstants.CGFloats.ChatPageView.AVSpeechSynthesizerDelegate

        let fullRange = NSRange(location: 0, length: attributedString.length)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Floats.attributedStringParagraphStyleLineSpacing

        attributedString.addAttribute(
            .foregroundColor,
            value: UIColor(shouldUseWhite ? Colors.willSpeakRangeOfSpeechStringWhite : Colors.willSpeakRangeOfSpeechStringNotWhite),
            range: fullRange
        )

        attributedString.addAttribute(
            .foregroundColor,
            value: UIColor(Colors.willSpeakRangeOfSpeechStringHighlight),
            range: characterRange
        )

        attributedString.addAttribute(
            .font,
            value: labelFont,
            range: fullRange
        )

        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: fullRange
        )

        speakingCell.messageLabel.attributedText = attributedString
    }
}
