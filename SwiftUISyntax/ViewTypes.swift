//
//  ViewTypes.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 08/03/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
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

struct ViewModifiers {
    static let borders = ["overlay"]
    static let modifiers = ["alignment", "padding", "frame", "shadow", "clipShape", "offset", "cornerRadius"]
    static let navigations = ["navigationBarTitle"]
    static let scaleFits = ["scaledToFill", "scaledToFit"]
    static let styles = ["font", "foregroundColor"]
    static let tints = ["foregroundColor"]
}
