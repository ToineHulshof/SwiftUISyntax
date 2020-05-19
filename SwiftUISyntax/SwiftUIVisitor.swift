//
//  VisitTokens.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 05/03/2020.
//  Copyright c 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax

class SwiftUIVisitor: SyntaxVisitor {
    
    var translations = [String]()
    
    func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        translations.append(StructTranslator(node: node).translate())
        return .skipChildren
    }
    
    func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
        translations.append(ImportTranslator(node: node).translate())
        return .skipChildren
    }
    
    func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        var s = ""
        if node.inheritanceClause?.inheritedTypeCollection.contains(where: { $0.withoutTrivia().typeName.description == "ObservableObject" }) ?? false {
            s += "@Model\n"
            s += "object " + node.identifier.text + " {\n"
            node.members.members.forEach { member in
                guard let varDecl = member.decl as? VariableDeclSyntax else { return }
                s += "\t\(varDecl.letOrVarKeyword.withoutTrivia()) \(varDecl.bindings.withoutTrivia())\n"
            }
            s += "}"
        } else {
            KotlinTokenizer().translate(content: node.description).tokens?.forEach({ token in
                s += token.value
            })
        }
        translations.append(s)
        return .skipChildren
    }
    
    func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.identifier.text == "load" {
            let s = """
            fun getJsonDataFromAsset(context: Context, fileName: String): String? {
                val jsonString: String
                try {
                    jsonString = context.assets.open(fileName).bufferedReader().use { it.readText() }
                } catch (ioException: IOException) {
                    ioException.printStackTrace()
                    return null
                }
                return jsonString
            }
            """
            translations.append(s)
        }
        return .skipChildren
    }
    
    func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        node.bindings.forEach { binding in
            guard let funcExpr = binding.initializer?.value as? FunctionCallExprSyntax, let type = binding.typeAnnotation else { return }
            if funcExpr.calledExpression.description == "load" {
                let typeDescription = type.type.description.replacingOccurrences(of: "[", with: "Array<").replacingOccurrences(of: "]", with: ">").trimmingCharacters(in: .whitespaces)
                translations.append("val \(binding.pattern) = Gson().fromJson(getJsonDataFromAsset(MyApplication.appContext!!, \(funcExpr.argumentList.description), \(typeDescription))::class.java)\(typeDescription.contains("Array") ? ".asList()" : "")")
            }
        }
        return .skipChildren
    }
    
    func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        var s = ""
        KotlinTokenizer().translate(content: node.description).tokens?.forEach({ token in
            s += token.value
        })
        translations.append(s)
        return .skipChildren
    }
    
}
