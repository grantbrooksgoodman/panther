//
//  DevModeActions+Breadcrumbs.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 19/09/2025.
//  Copyright © 2013-2025 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum Breadcrumbs {
        // MARK: - Manage Breadcrumbs Capture Action

        static var manageBreadcrumbsCaptureAction: DevModeAction {
            @Sendable
            func manageBreadcrumbsCapture() {
                Task { @MainActor in
                    @Dependency(\.commonServices.metadata) var metadataService: MetadataService
                    @Dependency(\.uiApplication) var uiApplication: UIApplication
                    @Dependency(\.uiPasteboard) var uiPasteboard: UIPasteboard

                    let clearBreadcrumbsCaptureHistoryAction: AKAction = .init(
                        "Clear Capture History",
                        style: .destructive,
                        effect: Breadcrumbs.presentClearBreadcrumbsCaptureHistoryActionSheet
                    )

                    let openHostedBreadcrumbsDirectoryAction: AKAction = .init(
                        "Open Hosted Directory",
                        effect: Breadcrumbs.openHostedBreadcrumbsDirectory
                    )

                    let setBreadcrumbsCaptureFrequencyAction: AKAction = .init(
                        "Set Capture Frequency",
                        effect: Breadcrumbs.presentBreadcrumbsCaptureFrequencyTextInputAlert
                    )

                    await AKActionSheet(
                        title: "Manage Hosted Breadcrumbs Capture",
                        actions: [
                            openHostedBreadcrumbsDirectoryAction,
                            clearBreadcrumbsCaptureHistoryAction,
                            setBreadcrumbsCaptureFrequencyAction,
                        ]
                    ).present(translating: [])
                }
            }

            return .init(
                title: "Manage Breadcrumbs Capture",
                perform: manageBreadcrumbsCapture
            )
        }

        // MARK: - Auxiliary

        private static func openHostedBreadcrumbsDirectory() {
            Task { @MainActor in
                @Dependency(\.build) var build: Build
                @Dependency(\.commonServices.metadata) var metadataService: MetadataService
                @Dependency(\.uiApplication) var uiApplication: UIApplication

                guard let storageReferenceURLString = metadataService.storageReferenceURL?.absoluteString,
                      let url = URL(string: [
                          storageReferenceURLString,
                          Networking.config.environment.shortString,
                          NetworkPath.breadcrumbs.rawValue,
                          build.bundleVersion,
                          build.bundleRevision,
                          "\(build.buildNumber)\(build.milestone.shortString)",
                      ].joined(separator: "~2F")) else { return }

                uiApplication.open(url)
            }
        }

        private static func presentBreadcrumbsCaptureFrequencyTextInputAlert() {
            Task { @MainActor in
                @Dependency(\.commonServices.breadcrumbsCapture) var breadcrumbsCaptureService: BreadcrumbsCaptureService
                @Dependency(\.coreKit) var core: CoreKit
                @Dependency(\.uiApplication) var uiApplication: UIApplication

                func presentTryAgainAlert() async {
                    let tryAgainAction: AKAction = .init(
                        "Try Again",
                        effect: presentBreadcrumbsCaptureFrequencyTextInputAlert
                    )

                    await AKAlert(
                        message: "The input was invalid. Please try again.",
                        actions: [
                            tryAgainAction,
                            .cancelAction,
                        ]
                    ).present(translating: [])
                }

                let textInputAlert: AKTextInputAlert = .init(
                    title: "Change Capture Frequency",
                    message: "Enter a capture frequency in seconds:",
                    attributes: .init(
                        keyboardType: .decimalPad,
                        placeholderText: String(breadcrumbsCaptureService.captureFrequency)
                            .removingOccurrences(of: [".0", "seconds"])
                            .trimmingBorderedWhitespace,
                    )
                )

                textInputAlert.onTextFieldChange { textField in
                    if let text = textField?.text {
                        guard !text.digits.isEmpty,
                              Double(text) != nil else { return textInputAlert.disableAction(at: 1) }
                        textInputAlert.enableAction(at: 1)
                    }
                }

                @MainActor
                func disableAction() {
                    guard uiApplication.isPresentingAlertController else {
                        Task.delayed(by: .milliseconds(100)) { @MainActor in
                            disableAction()
                        }
                        return
                    }

                    textInputAlert.disableAction(at: 1)
                }

                disableAction()
                guard let input = await textInputAlert.present(translating: []) else { return }
                guard let double = Double(input) else { return await presentTryAgainAlert() }

                breadcrumbsCaptureService.setCaptureFrequency(.seconds(double))
                core.hud.showSuccess()
            }
        }

        private static func presentClearBreadcrumbsCaptureHistoryActionSheet() {
            Task {
                @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD

                @Sendable
                func clearRemoteCaptureHistory() {
                    Task { @MainActor in
                        @Dependency(\.networking.storage) var storage: any StorageDelegate

                        let isCapturing = AppSubsystem.delegates.breadcrumbsCapture.isCapturing
                        AppSubsystem.delegates.breadcrumbsCapture.stopCapture()

                        coreHUD.showProgress(isModal: true)
                        defer {
                            coreHUD.hide()
                            if isCapturing { AppSubsystem.delegates.breadcrumbsCapture.startCapture() }
                        }

                        if let exception = await storage.deleteAllItems(
                            at: NetworkPath.breadcrumbs.rawValue,
                            includeItemsInSubdirectories: true,
                            timeout: .seconds(300)
                        ) {
                            Logger.log(exception, with: .toast)
                        } else {
                            Task.delayed(by: .seconds(1)) { @MainActor in
                                coreHUD.showSuccess()
                            }
                        }
                    }
                }

                let hostedOnlyAction: AKAction = .init(
                    "Hosted Only",
                    style: .destructive,
                ) { clearRemoteCaptureHistory() }

                let localAndHostedAction: AKAction = .init(
                    "Local and Hosted",
                    style: .destructivePreferred,
                ) {
                    @Persistent(.breadcrumbsCaptureHistory) var breadcrumbsCaptureHistory: Set<String>?
                    breadcrumbsCaptureHistory = nil
                    clearRemoteCaptureHistory()
                }

                let localOnlyAction: AKAction = .init("Local Only") {
                    @Persistent(.breadcrumbsCaptureHistory) var breadcrumbsCaptureHistory: Set<String>?
                    breadcrumbsCaptureHistory = nil
                    coreHUD.showSuccess()
                }

                await AKActionSheet(
                    title: "Clear Breadcrumbs Capture History", // swiftlint:disable:next line_length
                    message: "Select the type of history to clear.\n\nClearing hosted capture history will delete ALL hosted breadcrumbs in the \(Networking.config.environment.description.uppercased()) environment.",
                    actions: [
                        hostedOnlyAction,
                        localOnlyAction,
                        localAndHostedAction,
                    ],
                ).present(translating: [])
            }
        }
    }
}
