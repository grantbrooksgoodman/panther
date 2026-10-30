//
//  DevModeActions+DatabaseOptions.swift
//  Panther
//
//  Created by Grant Brooks Goodman on 05/08/2026.
//  Copyright © 2013-2026 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

/* Proprietary */
import AlertKit
import AppSubsystem
import Networking

extension DevModeAction.AppActions {
    enum DatabaseOptions {
        // MARK: - Properties

        /// The destination that pushes the database options page. Its actions apply to the
        /// current networking environment.
        static let action: DevModeAction = .init(
            title: "Database Options",
            iconConfiguration: .init(
                backgroundColor: .blue,
                overlay: .symbol(name: "cylinder.fill")
            ),
            destination: [
                migrateDatabaseAction,
                RollbackOptions.action,
                validateDatabaseIntegrityAction,
            ]
        )

        private static let migrateDatabaseAction: DevModeAction = {
            @Sendable
            func migrateDatabase() {
                Task { @MainActor in
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.networking.schemaMigrationService) var schemaMigrationService: SchemaMigrationService
                    @Dependency(\.rollbackService) var rollbackService: RollbackService

                    guard await AKConfirmationAlert(
                        title: "Migrate Database", // swiftlint:disable:next line_length
                        message: "This will migrate all database nodes in the \(Networking.config.environment.rawValue.uppercased()) to the version 5+ schema.\n\nA snapshot will be captured for rollback before migration."
                    ).present(translating: []) else { return }

                    do throws(Exception) {
                        try await rollbackService.captureSnapshot()
                        try await schemaMigrationService.migrateDatabase()
                        Task.delayed(by: .seconds(1)) { @MainActor in
                            coreHUD.flash(image: .success)
                        }
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Migrate Database",
                iconConfiguration: .init(
                    backgroundColor: .cyan,
                    overlay: .symbol(name: "arrow.triangle.2.circlepath")
                ),
                perform: migrateDatabase
            )
        }()

        private static let validateDatabaseIntegrityAction: DevModeAction = {
            @Sendable
            func validateDatabaseIntegrity() {
                Task { @MainActor in
                    @Dependency(\.networking.integrityService) var integrityService: IntegrityService

                    let progressAlert = AKProgressAlert(
                        title: "Validate Database Integrity",
                        message: "Please wait..."
                    )

                    await progressAlert.present(translating: [])
                    defer { progressAlert.dismiss() }

                    do throws(Exception) {
                        try await integrityService.repairDatabase { progressAlert.updateProgress($0) }
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Validate Database Integrity",
                iconConfiguration: .init(
                    backgroundColor: .green,
                    overlay: .symbol(name: "checkmark.shield.fill")
                ),
                perform: validateDatabaseIntegrity
            )
        }()
    }
}

private extension DevModeAction.AppActions {
    enum RollbackOptions {
        // MARK: - Properties

        static let action: DevModeAction = .init(
            title: "Rollback Options",
            iconConfiguration: .init(
                backgroundColor: .orange,
                overlay: .symbol(name: "clock.arrow.circlepath")
            ),
            destination: [
                captureSnapshotAction,
                rollbackToLatestSnapshotAction,
            ]
        )

        private static let captureSnapshotAction: DevModeAction = {
            @Sendable
            func captureSnapshot() {
                Task {
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.rollbackService) var rollbackService: RollbackService

                    coreHUD.showProgress(isModal: true)
                    defer { coreHUD.hide() }

                    do throws(Exception) {
                        try await rollbackService.captureSnapshot(
                            of: Networking.config.environment
                        )

                        coreHUD.hide()
                        Task.delayed(by: .seconds(1)) { @MainActor in
                            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                            coreHUD.flash(image: .success)
                        }
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Capture Snapshot",
                iconConfiguration: .init(
                    backgroundColor: .cyan,
                    overlay: .symbol(name: "externaldrive.fill.badge.plus")
                ),
                perform: captureSnapshot
            )
        }()

        private static let rollbackToLatestSnapshotAction: DevModeAction = {
            @Sendable
            func rollbackToLatestSnapshot() {
                Task {
                    @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                    @Dependency(\.rollbackService) var rollbackService: RollbackService
                    @Dependency(\.clientSession.entity.user) var userSession: UserSessionService

                    guard await AKConfirmationAlert(
                        title: "Rollback to Latest Snapshot", // swiftlint:disable:next line_length
                        message: "The \(Networking.config.environment.description.uppercased()) environment will be rolled back to its latest snapshot.\n\nThis operation cannot be undone.",
                        confirmButtonStyle: .destructivePreferred
                    ).present(translating: []) else { return }

                    coreHUD.showProgress(isModal: true)
                    defer { coreHUD.hide() }

                    do throws(Exception) {
                        userSession.stopObservingCurrentUserChanges()
                        try await rollbackService.rollbackToLatestSnapshot(
                            in: Networking.config.environment
                        )

                        coreHUD.hide()
                        Task.delayed(by: .seconds(1)) { @MainActor in
                            @Dependency(\.coreKit.hud) var coreHUD: CoreKit.HUD
                            coreHUD.flash(image: .success)
                            Application.reset(
                                preserveCurrentUserID: true,
                                onCompletion: .navigateToSplash
                            )
                        }
                    } catch {
                        Logger.log(
                            error,
                            with: .toast
                        )
                    }
                }
            }

            return DevModeAction(
                title: "Rollback to Latest Snapshot",
                iconConfiguration: .init(
                    backgroundColor: .orange,
                    overlay: .symbol(name: "arrow.uturn.backward.circle.fill")
                ),
                isDestructive: true,
                perform: rollbackToLatestSnapshot
            )
        }()
    }
}
