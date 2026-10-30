//
//  DevModeActions+UIOptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/08/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit
import WebKit

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum UIOptions {
        // MARK: - Properties

        /// The destination that pushes the UI options page. Its actions reflect the app's
        /// current state.
        @MainActor
        static var action: DevModeAction {
            @Dependency(\.uiApplication.presentedViews) var presentedViews: [UIView]

            var actions = [
                Breadcrumbs.action,
                triggerForcedUpdateModalAction,
            ]

            if presentedViews.contains(where: { $0 is WKWebView }) {
                actions.append(toggleWebViewVisibilityAction)
            }

            return .init(
                title: "UI Options",
                iconConfiguration: .init(
                    backgroundColor: .teal,
                    overlay: .symbol(name: "rectangle.3.group.fill")
                ),
                destination: actions
            )
        }

        private static let toggleWebViewVisibilityAction: DevModeAction = {
            @Sendable
            func toggleWebViewVisibility() {
                Task { @MainActor in
                    @Dependency(\.uiApplication.presentedViews) var presentedViews: [UIView]
                    let webViews = presentedViews.compactMap { $0 as? WKWebView }

                    guard !webViews.isEmpty else { return }
                    guard webViews.count > 1 else {
                        return webViews[0].toggleVisibility()
                    }

                    await AKActionSheet(
                        title: "Select Web View",
                        message: "Select the web view whose visibility to toggle.",
                        actions: webViews.map { webView in
                            let webView = UncheckedSendable(webView)
                            return AKAction(
                                "\(webView.wrappedValue.memoryAddress) (\(webView.wrappedValue.isVisible ? "Showing" : "Hidden"))"
                            ) {
                                Task { @MainActor in
                                    webView.wrappedValue.toggleVisibility()
                                }
                            }
                        }
                    ).present()
                }
            }

            return DevModeAction(
                title: "Toggle Web View Visibility",
                iconConfiguration: .init(
                    backgroundColor: .indigo,
                    overlay: .symbol(name: "eye.slash.fill")
                ),
                perform: toggleWebViewVisibility
            )
        }()

        private static let triggerForcedUpdateModalAction: DevModeAction = {
            @Sendable
            func triggerForcedUpdateModal() {
                SharedState(\.isForcedUpdateRequired).wrappedValue = true
            }

            return DevModeAction(
                title: "Trigger Forced Update Modal",
                iconConfiguration: .init(
                    backgroundColor: .purple,
                    overlay: .symbol(name: "arrow.down.app.fill")
                ),
                perform: triggerForcedUpdateModal
            )
        }()
    }
}

private extension DevModeAction.AppActions {
    enum Breadcrumbs {
        // MARK: - Properties

        static let action: DevModeAction = .init(
            title: "Manage Breadcrumbs Capture",
            iconConfiguration: .init(
                backgroundColor: .orange,
                overlay: .symbol(name: "camera.fill")
            ),
            destination: [
                clearCaptureHistoryAction,
                openHostedDirectoryAction,
                setCaptureFrequencyAction,
            ]
        )

        private static let clearCaptureHistoryAction: DevModeAction = .init(
            title: "Clear Capture History",
            iconConfiguration: .init(
                backgroundColor: .red,
                overlay: .symbol(name: "clock.badge.xmark")
            ),
            isDestructive: true,
            perform: presentClearCaptureHistoryActionSheet
        )

        private static let openHostedDirectoryAction: DevModeAction = .init(
            title: "Open Hosted Directory",
            iconConfiguration: .init(
                backgroundColor: .brown,
                overlay: .symbol(name: "folder.fill")
            ),
            perform: openHostedDirectory
        )

        private static let setCaptureFrequencyAction: DevModeAction = .init(
            title: "Set Capture Frequency",
            iconConfiguration: .init(
                backgroundColor: .mint,
                overlay: .symbol(name: "metronome.fill")
            ),
            perform: presentCaptureFrequencyTextInputAlert
        )

        // MARK: - Auxiliary

        private static func openHostedDirectory() {
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

        private static func presentCaptureFrequencyTextInputAlert() {
            Task { @MainActor in
                @Dependency(\.commonServices.breadcrumbsCapture) var breadcrumbsCaptureService: BreadcrumbsCaptureService
                @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                @Dependency(\.uiApplication) var uiApplication: UIApplication

                func presentTryAgainAlert() async {
                    let tryAgainAction: AKAction = .init(
                        "Try Again",
                        effect: presentCaptureFrequencyTextInputAlert
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
                            .trimmingBorderedWhitespace
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
                coreHUD.showSuccess()
            }
        }

        private static func presentClearCaptureHistoryActionSheet() {
            Task {
                @Sendable
                func clearRemoteCaptureHistory() {
                    Task { @MainActor in
                        @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                        @Dependency(\.networking.storage) var storage: any StorageDelegate

                        let isCapturing = AppSubsystem.delegates.breadcrumbsCapture.isCapturing
                        try? AppSubsystem.delegates.breadcrumbsCapture.stopCapture()

                        coreHUD.showProgress(isModal: true)
                        defer {
                            coreHUD.hide()
                            if isCapturing {
                                try? AppSubsystem.delegates.breadcrumbsCapture.startCapture()
                            }
                        }

                        do throws(Exception) {
                            try await storage.deleteAllItems(
                                at: NetworkPath.breadcrumbs.rawValue,
                                includeItemsInSubdirectories: true,
                                timeout: .seconds(300)
                            )

                            Task.delayed(by: .seconds(1)) { @MainActor in
                                coreHUD.showSuccess()
                            }
                        } catch {
                            Logger.log(
                                error,
                                with: .toast
                            )
                        }
                    }
                }

                let hostedOnlyAction: AKAction = .init(
                    "Hosted Only",
                    style: .destructive
                ) { clearRemoteCaptureHistory() }

                let localAndHostedAction: AKAction = .init(
                    "Local and Hosted",
                    style: .destructivePreferred
                ) {
                    @Persistent(.breadcrumbsCaptureHistory) var breadcrumbsCaptureHistory: Set<String>?
                    breadcrumbsCaptureHistory = nil
                    clearRemoteCaptureHistory()
                }

                let localOnlyAction: AKAction = .init("Local Only") {
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
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
                    ]
                ).present(translating: [])
            }
        }
    }
}

private extension WKWebView {
    // MARK: - Properties

    var isVisible: Bool {
        !isHidden && alpha > 0
    }

    var memoryAddress: String {
        String(describing: Unmanaged.passUnretained(self).toOpaque())
    }

    // MARK: - Methods

    func toggleVisibility() {
        let shouldShow = !isVisible
        alpha = shouldShow ? 1 : 0
        isHidden = !shouldShow
        isUserInteractionEnabled = shouldShow
    }
}
