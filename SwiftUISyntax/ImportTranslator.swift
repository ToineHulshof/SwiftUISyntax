//
//  ImportTranslator.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 07/03/2020.
//  Copyright © 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax

struct ImportTranslator {
    
    let node: ImportDeclSyntax
    
    func translate() -> String {
        if node.path.description == "SwiftUI" { return "import androidx.*" }
//        return "import \(node.path.description)"
        return ""
    }
    
}
