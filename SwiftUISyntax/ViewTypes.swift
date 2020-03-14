//
//  ViewTypes.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 08/03/2020.
//  Copyright © 2020 Toine Hulshof. All rights reserved.
//

import Foundation

enum StackType {
    case HStack, VStack, ZStack
    var translation: String {
        switch self {
        case .HStack: return "Row"
        case .VStack: return "Column"
        case .ZStack: return "Stack"
        }
    }
}
