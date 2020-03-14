//
//  main.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 05/03/2020.
//  Copyright © 2020 Toine Hulshof. All rights reserved.
//

import SwiftSyntax
import Foundation

let file = CommandLine.arguments[1]
let url = URL(fileURLWithPath: file)
let sourceFile = try SyntaxParser.parse(url)
let visitor = VisitTokens()
_ = visitor.visit(sourceFile)
let translation = visitor.translations.joined(separator: "\n\n")
print(translation)
if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
    let fileURL = dir.appendingPathComponent("test.kt")
    do {
        try translation.write(to: fileURL, atomically: false, encoding: .utf8)
    } catch {
        print(error.localizedDescription)
    }
}
