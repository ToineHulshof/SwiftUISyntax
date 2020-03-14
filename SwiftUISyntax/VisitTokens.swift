//
//  VisitTokens.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 05/03/2020.
//  Copyright © 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax

class VisitTokens: SyntaxRewriter {
    
    var translations = [String]()
    
    override func visit(_ node: ImportDeclSyntax) -> DeclSyntax {
        translations.append(ImportTranslator(node: node).translate())
        return node
    }
    
    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        translations.append(StructTranslator(node: node).translate())
        return node
    }
    
}
