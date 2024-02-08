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

/* 3rd-party */
import Redux

extension ChatPageViewController: AVSpeechSynthesizerDelegate {
    // MARK: - Did Cancel Utterance

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {}

    // MARK: - Did Finish Utterance

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        @Dependency(\.chatPageViewService.menu) var menuService: MenuService?
        menuService?.dismissMenu()
    }

    // MARK: - Will Speak Range of Speech String

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {}
}
