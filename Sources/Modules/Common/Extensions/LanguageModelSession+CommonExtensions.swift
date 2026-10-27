//
//  LanguageModelSession+CommonExtensions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 25/10/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AppSubsystem
import LanguageModels

extension LanguageModelSession {
    // MARK: - Type Aliases

    private typealias Floats = AppConstants.CGFloats.CommonExtensions.LanguageModelSession

    // MARK: - Methods

    /// Sends the given prompt to the model and returns its replies,
    /// resubmitting the prompt if it fails to submit.
    ///
    /// A prompt that fails to submit never reaches the model, so
    /// resubmitting it cannot produce a duplicate reply. This method
    /// resubmits such a prompt after a short delay, a limited number
    /// of times, before it throws.
    ///
    /// - Parameter prompt: The prompt to send.
    ///
    /// - Returns: The model's replies, in the order to send them.
    ///
    /// - Throws: An `Exception` if the model cannot produce a reply.
    func response(
        to prompt: ChatGPTPrompt
    ) async throws(Exception) -> [String] {
        do throws(LanguageModelError) {
            return try await prompt.replies(from: response(
                to: prompt.text,
                retryCount: 0
            ))
        } catch {
            throw Exception(
                error,
                metadata: .init(sender: self)
            )
        }
    }

    // MARK: - Auxiliary

    private func response(
        to prompt: String,
        retryCount: Int
    ) async throws(LanguageModelError) -> String {
        do throws(LanguageModelError) {
            return try await response(to: prompt)
        } catch {
            guard case .submissionFailed = error,
                  retryCount < Int(Floats.submissionRetryCountMaximum) else {
                throw error
            }

            Logger.log(
                .init(
                    "Resubmitting prompt that failed to submit.",
                    isReportable: false,
                    userInfo: [
                        "Reason": error.localizedDescription,
                        "RetryCount": retryCount + 1,
                    ],
                    metadata: .init(sender: self)
                )
            )

            try? await Task.sleep(
                for: .milliseconds(Floats.submissionRetryDelayMilliseconds)
            )

            return try await response(
                to: prompt,
                retryCount: retryCount + 1
            )
        }
    }
}
