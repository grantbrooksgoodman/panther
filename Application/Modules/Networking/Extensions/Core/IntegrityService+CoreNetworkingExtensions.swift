//
//  IntegrityService+CoreNetworkingExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public extension IntegrityService {
    func repairDatabase() async -> Exception? {
        var exceptions = [Exception]()

        // Resolve Integrity Service Session

        if let exception = await resolveSession() {
            exceptions.append(exception)
        }

        // Prune Invalidated Caches

        if let exception = await pruneInvalidatedCaches() {
            exceptions.append(exception)
        }

        // Repair Malformed Data

        if let exception = await repairMalformedMessages() {
            exceptions.append(exception)
        }

        if let exception = await repairMalformedConversations() {
            exceptions.append(exception)
        }

        if let exception = await repairMalformedUsers() {
            exceptions.append(exception)
        }

        // Repair Broken Data

        if let exception = await resolveBrokenConversationChain() {
            exceptions.append(exception)
        }

        if let exception = await resolveBrokenMessageChain() {
            exceptions.append(exception)
        }

        if let exception = await resolveMismatchedParticipants() {
            exceptions.append(exception)
        }

        if let exception = await resolveNoAudioComponentMessages() {
            exceptions.append(exception)
        }

        if let exception = await resolveNoMediaComponentMessages() {
            exceptions.append(exception)
        }

        if let exception = await resolveNonExistentParticipants() {
            exceptions.append(exception)
        }

        if let exception = await resolveNonExistentTranslations() {
            exceptions.append(exception)
        }

        if let exception = await resolveOrphanedMessages() {
            exceptions.append(exception)
        }

        return exceptions.compiledException
    }
}
