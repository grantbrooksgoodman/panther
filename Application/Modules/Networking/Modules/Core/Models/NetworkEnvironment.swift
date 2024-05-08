//
//  NetworkEnvironment.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum NetworkEnvironment: String, Codable {
    // MARK: - Cases

    case development
    case staging
    case production

    // MARK: - Properties

    var description: String { rawValue.firstUppercase }
    var shortString: String {
        switch self {
        case .development:
            return "dev"
        case .staging:
            return "stage"
        case .production:
            return "prod"
        }
    }
}
