//
//  StructTranslator.swift
//  SwiftUISyntax
//
//  Created by Toine Hulshof on 07/03/2020.
//  Copyright © 2020 Toine Hulshof. All rights reserved.
//

import Foundation
import SwiftSyntax
import Foundation

struct StructTranslator {
    
    let node: StructDeclSyntax
    private var isPreview: Bool {
        node.inheritanceClause?.description.contains("PreviewProvider") ?? false
    }
    
    func translate() -> String {
        var s = ""
        if isPreview { s += "@Preview\n" }
        s += "@Composable\n"
        s += "fun \(node.identifier)"
        let (initializedMembers, uninitializedMembers, initializer) = splitMembers(node.members.members)
        if let initializer = initializer {
            s += initializer.parameters.description
        } else {
            s += "("
            uninitializedMembers.forEach { member in
                if let varDecl = member.decl as? VariableDeclSyntax {
                    s += varDecl.bindings.description + ", "
                }
            }
            if uninitializedMembers.count > 0 {
                s = String(s.dropLast(2))
            }
            s += ") "
        }
        s += "{" + newLine()
        initializedMembers.forEach { member in
            switch member.decl {
            case let varDecl as VariableDeclSyntax: s += tab() + translate(varDecl) + newLine()
            case let initDecl as InitializerDeclSyntax: print(initDecl.body?.description ?? "empty init")
            default: break
            }
        }
        s += "}"
        node.members.members.forEach { member in
            if let funcDecl = member.decl as? FunctionDeclSyntax {
                s += translate(funcDecl) + newLine()
            }
        }
        return s
    }
    
    func splitMembers(_ members: MemberDeclListSyntax) -> ([MemberDeclListItemSyntax], [MemberDeclListItemSyntax], InitializerDeclSyntax?) {
        var initializedMembers = [MemberDeclListItemSyntax]()
        var uninitializedMembers = [MemberDeclListItemSyntax]()
        var initializer: InitializerDeclSyntax? = nil
        members.forEach { member in
            switch member.decl {
            case let varDecl as VariableDeclSyntax:
                var shouldTranslate = false
                varDecl.bindings.forEach { pattern in
                    if pattern.initializer != nil || ((pattern.accessor as? CodeBlockSyntax) != nil) {
                        shouldTranslate = true
                    }
                }
                if let attributes = varDecl.attributes {
                    attributes.forEach { attribute in
                        if (attribute as? CustomAttributeSyntax) != nil {
                            shouldTranslate = true
                        }
                    }
                }
                shouldTranslate ? initializedMembers.append(member) : uninitializedMembers.append(member)
            case let initDecl as InitializerDeclSyntax: initializer = initDecl
            default: break
            }
        }
        return (initializedMembers, uninitializedMembers, initializer)
    }
        
    func translate(_ decl: DeclSyntax) -> String {
        switch decl {
        case let varDecl as VariableDeclSyntax: return translate(varDecl)
        case let funcDecl as FunctionDeclSyntax: return translate(funcDecl)
        default: return "unsupported\n"
        }
    }
    
    func translate(_ decl: VariableDeclSyntax) -> String {
        var s = ""
        if let name = decl.bindings.firstToken, let view = getView(decl.bindings), name.text == "previews" {
            return "MaterialTheme {\n\t\t\(translate(view, depth: 1))\n\t}"
        }
        if let name = decl.bindings.firstToken, let view = getView(decl.bindings), name.text == "body" {
            return translate(view, depth: 2)
        }
        switch decl.letOrVarKeyword.text {
        case "var": s += "val "
        case "let": s += "let "
        default: break
        }
        if let attribute = decl.attributes {
            s += decl.bindings.firstToken?.text ?? ""
            s += " = "
            switch attribute.description {
            case let str where str.contains("@State"): s += "+state{\(value(decl.bindings))}"
            case let str where str.contains("@ObservedObject"): s += "+observed{\(value(decl.bindings))}"
            case let str where str.contains("@Binding"): s += "+binding{\(value(decl.bindings))}"
            case let str where str.contains("@EnvironmentObject"): s += "+environment{\(value(decl.bindings))}"
            case let str where str.contains("@FetchRequest"): s += "+fetch{\(value(decl.bindings))}"
            default: break
            }
        } else {
            decl.bindings.forEach { binding in
                s += binding.withoutTrivia().description
            }
        }
        return s
    }
    
    func translate(_ codeBlock: CodeBlockSyntax, depth: Int) -> String {
        var s = ""
        codeBlock.statements.forEach { view in
            s += translateView(view, depth: depth)
        }
        return s
    }
    
    func translateView(_ view: CodeBlockItemSyntax, _ parent: StackType? = nil, depth: Int) -> String {
        var s = ""
        switch view.item {
        case let funcExpr as FunctionCallExprSyntax:
            switch funcExpr.calledExpression {
            case let idenExpr as IdentifierExprSyntax: s += translateViewBody(funcExpr, [], idenExpr, parent, depth)
            case let memExpr as MemberAccessExprSyntax: s += translate([(funcExpr, memExpr)], depth)
            default: break
            }
        case let memExpr as MemberAccessExprSyntax:
            if let base = memExpr.base {
                switch base {
                case let idenExpr as IdentifierExprSyntax:
                    switch idenExpr.identifier.text {
                    case "Color": s += "Color.\(memExpr.name.text.capitalizingFirstLetter())"
                    default: break
                    }
                default: break
                }
            }
        default: break
        }
        return s
    }
    
    func translate(_ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ depth: Int) -> String {
        guard let memExpr = modifiers.last?.1, let base = memExpr.base else { return "" }
        var s = ""
        switch base {
        case let funcExpr as FunctionCallExprSyntax:
            switch funcExpr.calledExpression {
            case let mem as MemberAccessExprSyntax: s += translate(modifiers + [(funcExpr, mem)], depth)
            case let iden as IdentifierExprSyntax: s += translateViewBody(funcExpr, modifiers, iden, nil, depth)
            default: break
            }
        default: break
        }
        ///TODO: viewmodifiers toevoegen
//        s += newLine() + tab(depth) + "."
//        switch memExpr.name.text {
//        case "foregroundColor": s += "color"
//        default: s += "custom modifier"
//        }
        return s
    }
    
    func translateModifier(_ modifier: (FunctionCallExprSyntax, MemberAccessExprSyntax), _ viewString: String, _ depth: Int) -> String {
        var s = ""
        switch modifier.1.name.text {
        case "padding": s += translatePadding(modifier.0.argumentList)
        case "font": s += "style = themeTextStyle { " + translateFont(modifier.0.argumentList) + " }"
        case "foregroundColor":
            s += "style = TextStyle(color = Color"
            modifier.0.argumentList.forEach { argument in
                let color = String(argument.expression.description.dropFirst())
                s += "." + color.capitalizingFirstLetter()
            }
            s += ")"
//        case "clipShape":
//            return "Clip(shape = RoundedCornerShape(8.dp)) {" + newLine() + tab(depth) + viewString + newLine() + tab(depth - 1) + "}"
        default: s += "\(modifier.1.name.text) not implemented yet"
        }
        return s
    }
    
    func translatePadding(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var s = ""
        s += "modifier = Spacing("
        arguments.forEach { argument in
            switch argument.expression {
            case let intLit as IntegerLiteralExprSyntax: s += intLit.description + ".dp"
            default: break
            }
        }
        if !s.contains(".dp") { s += "10.dp" }
        s += ")"
        return s
    }
    
    func translateViewBody(_ viewBody: FunctionCallExprSyntax, _ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ idenExpr: IdentifierExprSyntax, _ parent: StackType? = nil, _ depth: Int) -> String {
        var s = ""
        ///TODO: zo veel mogelijk views toevoegen
        switch idenExpr.identifier.text {
        case "VStack": s += translateStack(.VStack, viewBody, modifiers, depth)
        case "HStack": s += translateStack(.HStack, viewBody, modifiers, depth)
        case "ZStack": s += translateStack(.ZStack, viewBody, modifiers, depth)
        case "Text": s += translateText(viewBody, modifiers, depth)
        case "Button": s += translateButton(viewBody, depth)
        case "ForEach": s += translateForEach(viewBody, depth)
        case "AngularGradient": s += "AngularGradient not implemented yet"
        case "AnyView": s += "AnyView not implemented yet"
        case "ButtonStyleConfiguration.Label": s += "ButtonStyleConfiguration.Label not implemented yet"
        case "Color":
            s += "Color."
            print(viewBody)
        case "DatePicker": s += "DatePicker not implemented yet"
        case "Divider": s += "Divider not implemented yet"
        case "EditButton": s += "EditButton not implemented yet"
        case "EmptyView": s += "EmptyView not implemented yet"
        case "EquatableView": s += "EquatableView not implemented yet"
        case "Form": s += "Form not implemented yet"
        case "GeometryReader": s += "GeometryReader not implemented yet"
        case "Group": s += "Group not implemented yet"
        case "GroupBox": s += "GroupBox not implemented yet"
        case "HSplitView": s += "HSplitView not implemented yet"
        case "Image": s += translateImage(viewBody, modifiers, depth)
        case "LinearGradient": s += "LinearGradient not implemented yet"
        case "List": s += "List not implemented yet"
        case "MenuButton": s += "MenuButton not implemented yet"
        case "ModifiedContent": s += "ModifiedContent not implemented yet"
        case "NavigationLink": s += "NavigationLink not implemented yet"
        case "NavigationView": s += "NavigationView not implemented yet"
        case "Never": s += "Never not implemented yet"
        case "Optional": s += "Optional not implemented yet"
        case "PasteButton": s += "PasteButton not implemented yet"
        case "Picker": s += "Picker not implemented yet"
        case "PrimitiveButtonStyleConfiguration.Label": s += "PrimitiveButtonStyleConfiguration.Label not implemented yet"
        case "RadialGradient": s += "RadialGradient not implemented yet"
        case "ScrollView": s += "ScrollView not implemented yet"
        case "Section": s += "Section not implemented yet"
        case "SecureField": s += "SecureField not implemented yet"
        case "Slider": s += "Slider not implemented yet"
        case "Spacer":
            guard let parent = parent else { return s }
            s += "\(parent == .HStack ? "Width" : "Height")Spacer(\(parent == .HStack ? "width" : "height") = 16.dp)"
        case "Stepper": s += "Stepper not implemented yet"
        case "SubscriptionView": s += "SubscriptionView not implemented yet"
        case "TabView": s += "TabView not implemented yet"
        case "TextField": s += "TextField not implemented yet"
        case "Toggle": s += "Toggle not implemented yet"
        case "ToggleStyleConfiguration.Label": s += "ToggleStyleConfiguration.Label not implemented yet"
        case "TupleView": s += "TupleView not implemented yet"
        case "VSplitView": s += "VSplitView not implemented yet"
        default: s += translateCustom(viewBody, idenExpr)
        }
        s += ""
        return s
    }
    
    func translateModifiers(_ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ viewString: String, _ depth: Int) -> String {
        var s = ""
        modifiers.forEach { modifier in
            s += newLine() + tab(depth) + translateModifier(modifier, viewString, depth + 1) + ","
        }
        s = String(s.dropLast())
        return s
    }
    
    func translateImage(_ viewBody: FunctionCallExprSyntax, _ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ depth: Int) -> String {
        var s = ""
        s += "DrawImage(image = +imageResource(R.drawable.(\(viewBody.argumentList.description)))"
        s += translateModifiers(modifiers, s, depth)
        s += ")"
        return s
    }
    
    func translateForEach(_ viewBody: FunctionCallExprSyntax, _ depth: Int) -> String {
        guard let closure = viewBody.trailingClosure else { return "" }
        var s = ""
        var isFirsArgument = true
        viewBody.argumentList.forEach { argument in
            if isFirsArgument {
                s += argument.expression.description
                isFirsArgument = false
            }
        }
        s += ".forEach { \(closure.signature?.input?.description ?? "_ ")->\n"
        closure.statements.forEach { statement in
            s += tab(depth) + translateView(statement, depth: depth + 1)
        }
        s += newLine() + tab(depth - 1) + "}"
        return s
    }
    
    func translateCustom(_ funcExpr: FunctionCallExprSyntax, _ idenExpr: IdentifierExprSyntax) -> String {
        var s = ""
        s += idenExpr.identifier.text
        s += "("
        funcExpr.argumentList.forEach { argument in
            s += argument.expression.description
        }
        s += ")"
        return s
    }
    
    func translateButton(_ funcExpr: FunctionCallExprSyntax, _ depth: Int) -> String {
        var s = ""
        if let closureExpr = funcExpr.trailingClosure {
            s += "Button(text: \(funcExpr.argumentList.description), onClick = {\n"
            s += translateSwift(closureExpr.statements, depth)
            s += tab(depth-1) + ")}"
        } else {
            // Geen closure, maar action als argument
        }
        return s
    }
    
    func translateSwift(_ code: CodeBlockItemListSyntax, _ depth: Int) -> String {
        var s = ""
        code.forEach { statement in
            if let seq = statement.item as? SequenceExprSyntax {
                s += tab(depth)
                seq.elements.forEach { expr in
                    switch expr {
                    case let member as MemberAccessExprSyntax: s += translateMember(member)
                    case let biOp as BinaryOperatorExprSyntax: s += " \(biOp.withoutTrivia()) "
                    case let intLit as IntegerLiteralExprSyntax: s += intLit.withoutTrivia().description
                    default : break
                    }
                }
                s += "\n"
            } else {
                s += tab(depth)
                KotlinTokenizer().translate(content: statement.description).tokens?.forEach({ token in
                    s += token.value
                })
            }
        }
        return s
    }
    
    func translateMember(_ memAccExpr: MemberAccessExprSyntax) -> String {
        return "\(memAccExpr.name.withoutTrivia()).value"
    }
    
    func translateText(_ funcExpr: FunctionCallExprSyntax, _ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ depth: Int) -> String {
        var s = ""
        s += "Text(text = "
        funcExpr.argumentList.forEach { argument in
            if let string = argument.expression as? StringLiteralExprSyntax {
                s += translate(string) + ","
            } else {
                s += argument.expression.description + ","
            }
        }
        s += translateModifiers(modifiers, s, depth)
        s += ")"
        return s
    }
    
    func translateFont(_ arguments: FunctionCallArgumentListSyntax) -> String {
        var s = ""
        arguments.forEach { argument in
            guard let font = (argument.expression as? MemberAccessExprSyntax)?.name.text else { return }
            switch font {
            case "headline": s += "h6"
            case "caption": s += "caption"
            case "largeTitle": s += "h3"
            case "title": s += "h4"
            case "subheadline": s += "caption"
            case "callout": s += "caption"
            case "footnote": s += "caption"
            case "body": s += "body1"
            default: break
            }
        }
        return s
    }
    
    func translate(_ string: StringLiteralExprSyntax) -> String {
        var s = "\""
        string.segments.forEach { segment in
            if let interPolatedString = segment as? ExpressionSegmentSyntax {
                interPolatedString.expressions.forEach { expr in
                    if expr.expression.description.contains("%") { return }
                    s += "${"
                    s += "\(expr.expression.description).value"
                    s += "}"
                }
            }
        }
        s += "\""
        return s
    }
    
    func translateStack(_ stackType: StackType, _ funcExpr: FunctionCallExprSyntax, _ modifiers: [(FunctionCallExprSyntax, MemberAccessExprSyntax)], _ depth: Int) -> String {
        guard let closureExpr = funcExpr.trailingClosure else { return "" }
        var s = ""
        s += stackType.translation
        /// TODO: Argumenten van stacks (alignment en spacing enzo)
        if funcExpr.argumentList.count + modifiers.count > 0 {
            s += "("
            funcExpr.argumentList.forEach { argument in
                if let label = argument.label, label.text == "alignment" {
                    s += newLine() + tab(depth) + "crossAxisSize = LayoutSize.Expand" + ","
                    s += newLine() + tab(depth) + "mainAxisSize = LayoutSize.Expand" + ","

                }
            }
            s += translateModifiers(modifiers, s, depth)
            s += newLine() + tab(depth - 1) + ")"
        }
        s += " {\n"
        closureExpr.statements.forEach { view in
            s += tab(depth) + translateView(view, stackType, depth: depth + 1) + "\n"
        }
        s += tab(depth-1) + "}"
        return s
    }
    
    func getView(_ bindings: PatternBindingListSyntax) -> CodeBlockSyntax? {
        var codeSyntax: CodeBlockSyntax? = nil
        bindings.forEach { binding in
            codeSyntax = binding.accessor as? CodeBlockSyntax
        }
        return codeSyntax
    }
    
    func value(_ bindings: PatternBindingListSyntax) -> String {
        var s = ""
        bindings.forEach { pattern in
            s += pattern.initializer?.value.description ?? pattern.description
        }
        return s
    }
    
    func translate(_ decl: FunctionDeclSyntax) -> String {
        var s = "\n"
        let result = KotlinTokenizer().translate(content: decl.description)
        result.tokens?.forEach({ token in
            s += token.value
        })
        return s
    }
    
    func tab(_ count: Int = 1) -> String {
        String(repeating: "\t", count: count)
    }
    
    func newLine(_ count: Int = 1) -> String {
        String(repeating: "\n", count: count)
    }
    
}

extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}
