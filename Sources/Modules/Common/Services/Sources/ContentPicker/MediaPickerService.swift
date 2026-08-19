//
//  MediaPickerService.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@preconcurrency import PhotosUI

/* Proprietary */
import AlertKit
import AppSubsystem

/// Use ``MediaPickerService`` to choose a photo or video from the user's photo library.
///
/// Call ``present()`` to show the picker, and register a dismissal handler with
/// ``onDismiss(_:)`` to receive the selected item. Selected videos are copied to the app's
/// temporary directory before delivery.
@MainActor
final class MediaPickerService: PHPickerViewControllerDelegate {
    // MARK: - Dependencies

    @Dependency(\.coreKit) private var core: CoreKit
    @Dependency(\.fileManager) private var fileManager: FileManager

    // MARK: - Properties

    private var timeout: Timeout?
    private var _onDismiss: ((Callback<ContentPickerResult, Exception>?) -> Void)?

    // MARK: - Init

    /// Creates a media picker service.
    nonisolated init() {}

    // MARK: - Present

    /// Presents the system photo library picker.
    func present() {
        let viewController = PHPickerViewController(configuration: .init())
        viewController.delegate = self
        core.ui.present(viewController)
    }

    // MARK: - On Dismiss

    /// Registers a handler to run when the picker is dismissed.
    ///
    /// The handler receives the selected item on success, a failure if processing fails, or
    /// `nil` if the user cancels. The handler is cleared after it runs. Registering a new
    /// handler replaces any existing one.
    ///
    /// - Parameter perform: The handler to run.
    func onDismiss(_ perform: @escaping (Callback<ContentPickerResult, Exception>?) -> Void) {
        _onDismiss = perform
    }

    // MARK: - PHPickerViewControllerDelegate Conformance

    /// Presents a confirmation action sheet for the first selected item, then loads it and
    /// delivers the result to the dismissal handler.
    ///
    /// A modal progress indicator appears if loading takes longer than one second.
    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        guard !results.isEmpty else {
            picker.dismiss(animated: true)
            _onDismiss?(nil)
            return _onDismiss = nil
        }

        guard let firstResult = results.first else { return _onDismiss = nil }
        let itemProvider = LockIsolated(firstResult.itemProvider)

        let confirmAction: AKAction = .init("Confirm", style: .preferred) {
            Task.delayed(by: .milliseconds(250)) { @MainActor in
                picker.dismiss(animated: true)

                self.timeout = .init(after: .seconds(1)) {
                    Task { @MainActor [weak self] in
                        self?.core.hud.showProgress(isModal: true)
                    }
                }

                itemProvider.projectedValue.withValue {
                    if $0.canLoadObject(ofClass: UIImage.self) {
                        self.loadImage($0)
                    } else if $0.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                        self.loadVideo($0)
                    } else {
                        self.dismissReturningFailure(.init(
                            "Failed to process media.",
                            metadata: .init(sender: self)
                        ))
                    }
                }
            }
        }

        Task {
            await AKActionSheet(
                actions: [confirmAction],
                cancelButtonTitle: Localized(.cancel).wrappedValue
            ).present(translating: [.actions()])
        }
    }

    // MARK: - Auxiliary

    private func dismissReturningFailure(_ exception: Exception) {
        timeout?.cancel()
        core.hud.hide()

        _onDismiss?(.failure(exception))
        _onDismiss = nil
    }

    private func loadImage(_ itemProvider: NSItemProvider) {
        itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            let image = object as? UIImage
            Task { @MainActor in
                self.timeout?.cancel()
                self.core.hud.hide()

                guard let image else {
                    return self.dismissReturningFailure(.init(error, metadata: .init(sender: self)))
                }

                self._onDismiss?(.success(.image(image)))
                self._onDismiss = nil
            }
        }
    }

    private func loadVideo(_ itemProvider: NSItemProvider) {
        typealias Strings = AppConstants.Strings.ChatPageViewService.MediaActionHandler

        let fileManager = LockIsolated(fileManager)
        let temporaryFileName = "\(Strings.defaultVideoName).\(MediaFileExtension.video(.mp4).rawValue)"
        let temporaryFilePath = fileManager
            .wrappedValue
            .temporaryDirectory
            .appending(path: temporaryFileName)

        itemProvider.loadFileRepresentation(
            forTypeIdentifier: UTType.movie.identifier
        ) { @Sendable url, error in
            // The system deletes the source file when this handler returns;
            // the copy must complete synchronously here.
            let copyResult: Callback<URL, Exception>

            if let url {
                try? fileManager
                    .wrappedValue
                    .removeItem(atPath: temporaryFilePath.path())

                do {
                    try fileManager
                        .wrappedValue
                        .copyItem(
                            at: url,
                            to: temporaryFilePath
                        )

                    copyResult = .success(temporaryFilePath)
                } catch {
                    copyResult = .failure(.init(
                        error,
                        metadata: .init(sender: self)
                    ))
                }
            } else {
                copyResult = .failure(.init(
                    error,
                    metadata: .init(sender: self)
                ))
            }

            Task { @MainActor in
                self.timeout?.cancel()
                self.core.hud.hide()

                switch copyResult {
                case let .success(videoFilePath):
                    self._onDismiss?(.success(.video(videoFilePath)))
                    self._onDismiss = nil

                case let .failure(exception):
                    self.dismissReturningFailure(exception)
                }
            }
        }
    }
}
