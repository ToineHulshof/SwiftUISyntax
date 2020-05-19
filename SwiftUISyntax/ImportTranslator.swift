//
//  ImportTranslator.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 07/03/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax

struct ImportTranslator {
    
    let node: ImportDeclSyntax
    
    func translate() -> String {
        switch node.path.description {
        case "SwiftUI":
            return """
            import androidx.compose.Composable
            import androidx.ui.animation.*
            import androidx.ui.core.*
            import androidx.ui.foundation.*
            import androidx.ui.framework.*
            import androidx.ui.layout.*
            import androidx.ui.material.*
            import androidx.ui.tooling.*
            """
        case "Combine":
            return "import androidx.compose.Model"
        default: return ""
        }
    }
    
}
