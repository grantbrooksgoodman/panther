//
//  ContentPickerResult.swift
//  Panther
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import UIKit

public enum ContentPickerResult {
    case document(URL)
    case image(UIImage)
    case video(URL)
}
