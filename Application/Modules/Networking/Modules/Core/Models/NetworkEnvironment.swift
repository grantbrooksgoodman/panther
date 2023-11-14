//
//  NetworkEnvironment.swift
//  Delta
//
//  Created by Grant Brooks Goodman on 23/10/2023.
//  Copyright © 2013-2023 NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

public enum NetworkEnvironment: String {
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
